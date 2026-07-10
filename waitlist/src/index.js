// Grace's Holy Bell — waitlist Cloudflare Worker.
//
// Endpoints:
//   POST /                   Accept a waitlist signup (JSON), store it in D1,
//                            send confirmation + admin emails via Resend, and
//                            capture a `waitlist_signup` PostHog event.
//   GET  /r/<code>           Log a referral link click/scan in D1, capture a
//                            `referral_link_clicked` PostHog event, and 302
//                            redirect to the waitlist page (or the App Store,
//                            once REDIRECT_URL is set — see planning/
//                            referral-click-tracking-spec.md).
//   GET  /export.csv         Download all signups as CSV (token-protected) so
//                            they can be opened/imported into a spreadsheet.
//   GET  /export-clicks.csv  Download all referral clicks as CSV (same token).
//   GET  /app-config         Public, anonymous read of remotely-configurable
//                            app content (e.g. the idle-screen welcome
//                            message). See WELCOME_MESSAGE.md at the repo
//                            root.
//   POST /admin/app-config   Token-protected write of that same content.
//
// All form fields are optional, but a submission with no email/name/phone is
// rejected as empty. Signups are rate-limited per client IP (see rate_events
// in schema.sql) and duplicate emails are absorbed idempotently, so the
// endpoint can't be used to spam confirmations. See ../SETUP.md for deployment.

const MAX_LEN = 200;
const REF_CODE_RE = /^[a-z0-9]{4,16}$/;
const POSTHOG_CAPTURE_URL = "https://eu.i.posthog.com/i/v0/e/";

// Signup rate limit: max submissions per client IP per rolling window. The
// endpoint sends email on every accepted signup, so without this it is an
// open relay for spamming arbitrary addresses from our domain (and for
// burning the Resend quota / flooding D1).
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour

export default {
  async fetch(request, env, ctx) {
    return handleRequest(request, env, ctx);
  },
};

export async function handleRequest(request, env, ctx) {
  const allowed = (env.ALLOWED_ORIGIN || "https://boginfactory.com")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const origin = request.headers.get("Origin") || "";
  const cors = corsHeaders(origin, allowed);

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }

  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname.endsWith("/export.csv")) {
    return exportCsv(url, env);
  }

  if (request.method === "GET" && url.pathname.endsWith("/export-clicks.csv")) {
    return exportClicksCsv(url, env);
  }

  if (request.method === "GET" && (url.pathname === "/r" || url.pathname.startsWith("/r/"))) {
    return handleReferralClick(url, request, env, ctx);
  }

  if (request.method === "GET" && url.pathname === "/app-config") {
    return getAppConfig(env);
  }

  if (request.method === "POST" && url.pathname === "/admin/app-config") {
    return postAppConfig(request, env);
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, cors);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400, cors);
  }

  // Honeypot: bots fill hidden fields. Pretend success, store nothing.
  if (sanitize(body.website)) {
    return json({ ok: true }, 200, cors);
  }

  const data = {
    email: sanitize(body.email),
    name: sanitize(body.name),
    country: sanitize(body.country),
    phone: sanitize(body.phone),
    instagram: sanitize(body.instagram),
    referrer: sanitize(body.referrer),
    myCode: sanitize(body.myCode),
    // Which app surface produced the shared link ("phone"/"watch"), or "" if
    // unknown. Whitelisted so only the expected values are ever stored.
    source: body.source === "phone" || body.source === "watch" ? body.source : "",
    // Boolean from the form's SMS-authorization checkbox. Stored as "yes"/"no"
    // so the CSV is self-explanatory and the consent record is unambiguous.
    smsConsent: body.smsConsent === true || body.smsConsent === "yes" ? "yes" : "no",
  };

  if (data.email && !isEmail(data.email)) {
    return json({ error: "Invalid email" }, 400, cors);
  }
  if (!data.email && !data.name && !data.phone) {
    return json({ error: "Please enter at least one field" }, 400, cors);
  }

  if (!(await checkRateLimit(env, request))) {
    return json({ error: "Too many requests — please try again later" }, 429, cors);
  }

  // Duplicate email: pretend success without a second row or a second round of
  // emails. Keeps resubmits idempotent and stops repeat-POSTs from spamming
  // the address with confirmations.
  if (data.email && (await emailAlreadySignedUp(env, data.email))) {
    return json({ ok: true }, 200, cors);
  }

  const createdAt = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO signups (created_at, email, name, country, phone, instagram, sms_consent, referrer, my_code, source)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  )
    .bind(createdAt, data.email, data.name, data.country, data.phone, data.instagram, data.smsConsent, data.referrer, data.myCode, data.source)
    .run();

  // Emails are best-effort — storage already succeeded, so never fail the
  // request if Resend is unhappy.
  try {
    await sendEmails(env, data);
  } catch (err) {
    console.error("email send failed", err);
  }

  schedule(
    ctx,
    postHogCapture(env, {
      event: "waitlist_signup",
      distinctId: "ref:" + (data.referrer || "organic"),
      properties: {
        ref_code: data.referrer,
        new_code: data.myCode,
        source: data.source,
        has_email: Boolean(data.email),
        $process_person_profile: false,
      },
      timestamp: createdAt,
    })
  );

  return json({ ok: true }, 200, cors);
}

// ── Abuse guards (rate limit + dedupe) ──────────────────────────────────────
//
// Both guards FAIL OPEN: a D1 error (e.g. the rate_events table not yet
// migrated on the live DB) must never take signups down — it just means one
// unguarded request, logged for visibility.

async function checkRateLimit(env, request) {
  const ip = request.headers.get("CF-Connecting-IP") || "";
  if (!ip) return true; // no client IP (local dev/tests) — nothing to key on
  try {
    const ipHash = await sha256Hex(ip);
    const now = Date.now();
    const windowStart = new Date(now - RATE_LIMIT_WINDOW_MS).toISOString();
    const row = await env.DB.prepare(
      `SELECT COUNT(*) AS n FROM rate_events WHERE ip_hash = ? AND created_at > ?`
    )
      .bind(ipHash, windowStart)
      .first();
    if ((row?.n ?? 0) >= RATE_LIMIT_MAX) return false;
    await env.DB.prepare(`INSERT INTO rate_events (created_at, ip_hash) VALUES (?, ?)`)
      .bind(new Date(now).toISOString(), ipHash)
      .run();
    return true;
  } catch (err) {
    console.error("rate limit check failed (allowing request)", err);
    return true;
  }
}

async function emailAlreadySignedUp(env, email) {
  try {
    const row = await env.DB.prepare(`SELECT id FROM signups WHERE email = ? LIMIT 1`)
      .bind(email)
      .first();
    return Boolean(row);
  } catch (err) {
    console.error("email dedupe check failed (allowing request)", err);
    return false;
  }
}

// Only the hash of the IP is stored — enough to rate-limit, no address at rest.
async function sha256Hex(value) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// ── Referral click tracking ─────────────────────────────────────────────────

async function handleReferralClick(url, request, env, ctx) {
  const rawCode = url.pathname === "/r" ? "" : url.pathname.slice("/r/".length);
  const code = REF_CODE_RE.test(rawCode) ? rawCode : null;

  const src = url.searchParams.get("src");
  const source = src === "phone" || src === "watch" ? src : "";
  const device = classifyDevice(request.headers.get("User-Agent"));
  const country = request.cf?.country || "";
  const createdAt = new Date().toISOString();

  const redirectUrl = env.REDIRECT_URL
    ? env.REDIRECT_URL
    : "https://boginfactory.com/grace-waitlist.html?ref=" +
      encodeURIComponent(rawCode) +
      "&src=" +
      encodeURIComponent(source);
  const destination = env.REDIRECT_URL ? "appstore" : "waitlist";

  if (code) {
    schedule(
      ctx,
      (async () => {
        try {
          await env.DB.prepare(
            `INSERT INTO ref_clicks (created_at, code, source, device, country) VALUES (?, ?, ?, ?, ?)`
          )
            .bind(createdAt, code, source, device, country)
            .run();
        } catch (err) {
          console.error("ref click log failed", err);
        }
      })()
    );

    if (device !== "bot") {
      schedule(
        ctx,
        postHogCapture(env, {
          event: "referral_link_clicked",
          distinctId: "ref:" + code,
          properties: {
            ref_code: code,
            source,
            device,
            country,
            destination,
            $process_person_profile: false,
          },
          timestamp: createdAt,
        })
      );
    }
  }

  return new Response(null, {
    status: 302,
    headers: { Location: redirectUrl, "Cache-Control": "no-store" },
  });
}

function classifyDevice(userAgent) {
  const ua = (userAgent || "").toLowerCase();
  if (!ua) return "";
  if (/bot|crawler|preview/.test(ua)) return "bot";
  if (/iphone|ipad/.test(ua)) return "ios";
  if (/android/.test(ua)) return "android";
  return "desktop";
}

// ── Email ────────────────────────────────────────────────────────────────

async function sendEmails(env, data) {
  const apiKey = env.RESEND_API_KEY;
  if (!apiKey) {
    console.error("RESEND_API_KEY missing — skipping email send");
    return;
  }
  const from = env.FROM_EMAIL || "Grace's Holy Bell <gracesholybell@boginfactory.com>";

  const tasks = []; // { kind, to, send: Promise }

  if (data.email) {
    const shareURL =
      "https://boginfactory.com/grace-waitlist.html" +
      (data.myCode ? "?ref=" + encodeURIComponent(data.myCode) : "");
    tasks.push({
      kind: "confirmation",
      to: data.email,
      send: sendEmail(apiKey, {
        from,
        to: data.email,
        subject: "You're on the Grace's Holy Bell waitlist",
        html: confirmationHtml(data.name, shareURL),
      }),
    });
  }

  if (env.ADMIN_EMAIL) {
    tasks.push({
      kind: "admin",
      to: env.ADMIN_EMAIL,
      send: sendEmail(apiKey, {
        from,
        to: env.ADMIN_EMAIL,
        subject: "New Grace's Holy Bell waitlist signup",
        html: adminHtml(data),
      }),
    });
  }

  // Emails stay best-effort (storage already succeeded), but log every failure
  // so a bad sender/domain/key is visible in `wrangler tail` instead of silent.
  const results = await Promise.allSettled(tasks.map((t) => t.send));
  results.forEach((r, i) => {
    const { kind, to } = tasks[i];
    if (r.status === "rejected") {
      console.error(`EMAIL_FAIL ${kind} -> ${to}: ${String(r.reason)}`);
    } else {
      console.log(`EMAIL_OK ${kind} -> ${to}`);
    }
  });
}

async function sendEmail(apiKey, payload) {
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: "Bearer " + apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    throw new Error("Resend error " + res.status + ": " + (await res.text()));
  }
  return res;
}

function confirmationHtml(name, shareURL) {
  const greeting = name ? `Hi ${escapeHtml(name)},` : "Hi there,";
  // The app's pixel font (Press Start 2P) can't be relied on in email clients —
  // Gmail and others strip @font-face — so the title is a pre-rendered image in
  // that font (hosted alongside the web pages). Body text stays in a system
  // font but is centered to match the app's "You're on the list" page.
  return `
  <div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#c8d8b0;padding:24px;color:#1a2a0a;">
    <div style="max-width:480px;margin:0 auto;background:#c0d0a8;border:3px solid #a0b080;border-radius:10px;padding:28px 24px;text-align:center;">
      <img src="https://boginfactory.com/grace-waitlist-title.png" alt="You're on the list"
           width="252" style="display:block;margin:0 auto 22px;width:252px;max-width:100%;height:auto;">
      <p style="font-size:14px;line-height:1.7;color:#4a6a3a;margin:0 0 14px;">${greeting}</p>
      <p style="font-size:14px;line-height:1.7;color:#4a6a3a;margin:0 0 14px;">
        Thanks for joining the waiting list for <strong>Grace's Holy Bell</strong>.
        The app is still in beta &mdash; we'll reach out as soon as it's released.
      </p>
      <p style="font-size:14px;line-height:1.7;color:#4a6a3a;margin:0 0 8px;">
        Want to spread the word? Share your personal link:
      </p>
      <p style="font-size:13px;line-height:1.7;margin:0 0 22px;">
        <a href="${escapeAttr(shareURL)}" style="color:#5f7c4d;word-break:break-all;">${escapeHtml(shareURL)}</a>
      </p>
      <p style="font-size:11px;color:#4a6a3a;margin:0;">
        Grace's Holy Bell &middot; Boginfactory
      </p>
    </div>
  </div>`;
}

function adminHtml(data) {
  const row = (label, value) =>
    `<tr><td style="padding:4px 12px 4px 0;color:#4a6a3a;">${label}</td><td style="padding:4px 0;color:#1a2a0a;">${escapeHtml(value) || "&mdash;"}</td></tr>`;
  return `
  <div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#1a2a0a;">
    <h2 style="font-size:16px;">New waitlist signup</h2>
    <table style="font-size:14px;border-collapse:collapse;">
      ${row("Email", data.email)}
      ${row("Name", data.name)}
      ${row("Country", data.country)}
      ${row("Phone", data.phone)}
      ${row("Instagram", data.instagram)}
      ${row("SMS consent", data.smsConsent)}
      ${row("Referrer code", data.referrer)}
      ${row("Their code", data.myCode)}
      ${row("Source", data.source)}
    </table>
  </div>`;
}

// ── PostHog server-side capture ─────────────────────────────────────────────
//
// Best-effort and non-blocking, same philosophy as the Resend emails above:
// a missing key, a network error, or a non-2xx response must never affect the
// redirect or signup response. `ctx.waitUntil` lets the capture finish after
// the response is already on its way back to the client.

function schedule(ctx, promise) {
  if (ctx && typeof ctx.waitUntil === "function") {
    ctx.waitUntil(promise);
  } else {
    promise.catch(() => {});
  }
}

async function postHogCapture(env, { event, distinctId, properties, timestamp }) {
  const apiKey = env.POSTHOG_API_KEY;
  if (!apiKey) return;
  try {
    await fetch(POSTHOG_CAPTURE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: apiKey,
        event,
        distinct_id: distinctId,
        properties,
        timestamp,
      }),
    });
  } catch (err) {
    console.error("posthog capture failed", event, err);
  }
}

// ── Remote app config (welcome message, etc.) ───────────────────────────────
//
// The Worker is intentionally schema-agnostic about the *contents* of each
// config value — the app is the tolerant interpreter (see WELCOME_MESSAGE.md).
// This keeps future block/audience types addable without a Worker redeploy.

const APP_CONFIG_MAX_VALUE_BYTES = 32 * 1024;

async function getAppConfig(env) {
  const headers = {
    "Content-Type": "application/json",
    "Cache-Control": "public, max-age=300",
  };
  try {
    const { results } = await env.DB.prepare(`SELECT key, value FROM app_config`).all();
    const config = {};
    for (const row of results || []) {
      try {
        config[row.key] = JSON.parse(row.value);
      } catch (err) {
        // Corrupt row — skip it rather than breaking the whole response.
        console.error("app_config row has invalid JSON, skipping", row.key, err);
      }
    }
    return new Response(JSON.stringify(config), { status: 200, headers });
  } catch (err) {
    console.error("app-config read failed (returning empty)", err);
    return new Response(JSON.stringify({}), { status: 200, headers });
  }
}

async function postAppConfig(request, env) {
  const auth = request.headers.get("Authorization") || "";
  if (!env.ADMIN_TOKEN || auth !== "Bearer " + env.ADMIN_TOKEN) {
    return json({ error: "Unauthorized" }, 401, {});
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400, {});
  }

  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return json({ error: "Body must be a JSON object mapping keys to values" }, 400, {});
  }

  const entries = Object.entries(body);
  const serializedByKey = {};
  for (const [key, value] of entries) {
    const serialized = JSON.stringify(value);
    if (new TextEncoder().encode(serialized).length > APP_CONFIG_MAX_VALUE_BYTES) {
      return json({ error: `Value for "${key}" exceeds ${APP_CONFIG_MAX_VALUE_BYTES} byte limit` }, 400, {});
    }
    serializedByKey[key] = serialized;
  }

  const updatedAt = new Date().toISOString();
  for (const [key, serialized] of Object.entries(serializedByKey)) {
    await env.DB.prepare(
      `INSERT INTO app_config (key, value, updated_at) VALUES (?1, ?2, ?3)
       ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`
    )
      .bind(key, serialized, updatedAt)
      .run();
  }

  return getAppConfig(env);
}

// ── CSV export ─────────────────────────────────────────────────────────────

async function exportClicksCsv(url, env) {
  const token = url.searchParams.get("token") || "";
  if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
    return new Response("Unauthorized", { status: 401 });
  }
  const { results } = await env.DB.prepare(
    `SELECT created_at, code, source, device, country FROM ref_clicks ORDER BY id DESC`
  ).all();

  const header = ["created_at", "code", "source", "device", "country"];
  const lines = [header.join(",")];
  for (const r of results || []) {
    lines.push(header.map((h) => csvCell(r[h])).join(","));
  }
  return new Response(lines.join("\n"), {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="grace-waitlist-clicks.csv"',
    },
  });
}

async function exportCsv(url, env) {
  const token = url.searchParams.get("token") || "";
  if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) {
    return new Response("Unauthorized", { status: 401 });
  }
  const { results } = await env.DB.prepare(
    `SELECT created_at, email, name, country, phone, instagram, sms_consent, referrer, my_code, source
     FROM signups ORDER BY id DESC`
  ).all();

  const header = ["created_at", "email", "name", "country", "phone", "instagram", "sms_consent", "referrer", "my_code", "source"];
  const lines = [header.join(",")];
  for (const r of results || []) {
    lines.push(header.map((h) => csvCell(r[h])).join(","));
  }
  return new Response(lines.join("\n"), {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": 'attachment; filename="grace-waitlist.csv"',
    },
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────

function sanitize(v) {
  if (typeof v !== "string") return "";
  return v.trim().slice(0, MAX_LEN);
}

function isEmail(v) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
}

function corsHeaders(origin, allowed) {
  const ok = allowed.includes(origin);
  return {
    "Access-Control-Allow-Origin": ok ? origin : allowed[0] || "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

function json(obj, status, headers) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

function csvCell(v) {
  let s = (v ?? "").toString();
  // Neutralize spreadsheet formula injection: a leading =, +, -, @, or tab in
  // attacker-supplied text (name, email, …) would execute when the admin opens
  // the export in Excel/Sheets. The apostrophe forces text interpretation.
  if (/^[=+\-@\t\r]/.test(s)) s = "'" + s;
  return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

function escapeHtml(v) {
  return (v ?? "")
    .toString()
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function escapeAttr(v) {
  return escapeHtml(v).replace(/'/g, "&#39;");
}
