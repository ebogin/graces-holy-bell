// Grace's Holy Bell — waitlist Cloudflare Worker.
//
// Endpoints:
//   POST /              Accept a waitlist signup (JSON), store it in D1, and
//                       send confirmation + admin emails via Resend.
//   GET  /export.csv    Download all signups as CSV (token-protected) so they
//                       can be opened/imported into a spreadsheet.
//
// All form fields are optional, but a submission with no email/name/phone is
// rejected as empty. See ../SETUP.md for deployment.

const MAX_LEN = 200;

export default {
  async fetch(request, env) {
    return handleRequest(request, env);
  },
};

export async function handleRequest(request, env) {
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

  return json({ ok: true }, 200, cors);
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

// ── CSV export ─────────────────────────────────────────────────────────────

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
  const s = (v ?? "").toString();
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
