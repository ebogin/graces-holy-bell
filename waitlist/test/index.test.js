// Unit tests for the waitlist Worker handler.
// Run with: node --test   (no Cloudflare account or wrangler needed)
//
// We mock the D1 binding and global fetch (Resend) so the handler's logic can
// be exercised locally.

import { test } from "node:test";
import assert from "node:assert/strict";
import { handleRequest } from "../src/index.js";

// ── Mocks ──────────────────────────────────────────────────────────────────

function makeDB() {
  const inserted = [];
  const rows = [];
  const clicksInserted = [];
  const clickRows = [];
  return {
    inserted,
    rows,
    clicksInserted,
    clickRows,
    prepare(sql) {
      if (/ref_clicks/i.test(sql)) {
        return {
          _sql: sql,
          _args: [],
          bind(...args) {
            this._args = args;
            return this;
          },
          async run() {
            if (/INSERT/i.test(this._sql)) {
              clicksInserted.push(this._args);
              clickRows.push({
                created_at: this._args[0],
                code: this._args[1],
                source: this._args[2],
                device: this._args[3],
                country: this._args[4],
              });
            }
            return { success: true };
          },
          async all() {
            return { results: clickRows };
          },
        };
      }
      return {
        _sql: sql,
        _args: [],
        bind(...args) {
          this._args = args;
          return this;
        },
        async run() {
          if (/INSERT/i.test(this._sql)) {
            inserted.push(this._args);
            rows.push({
              created_at: this._args[0],
              email: this._args[1],
              name: this._args[2],
              country: this._args[3],
              phone: this._args[4],
              instagram: this._args[5],
              sms_consent: this._args[6],
              referrer: this._args[7],
              my_code: this._args[8],
              source: this._args[9],
            });
          }
          return { success: true };
        },
        async all() {
          return { results: rows };
        },
      };
    },
  };
}

function makeEnv(overrides = {}) {
  return {
    DB: makeDB(),
    ALLOWED_ORIGIN: "https://boginfactory.com",
    RESEND_API_KEY: "test-key",
    FROM_EMAIL: "Grace's Holy Bell <gracesholybell@boginfactory.com>",
    ADMIN_EMAIL: "gracesholybell@boginfactory.com",
    ADMIN_TOKEN: "secret-token",
    ...overrides,
  };
}

// A ctx whose waitUntil eagerly awaits the promise so tests can assert on
// best-effort work (PostHog capture, click logging) without racing it.
function makeCtx() {
  const waited = [];
  return {
    waited,
    waitUntil(promise) {
      waited.push(promise);
    },
    async flush() {
      await Promise.allSettled(waited);
    },
  };
}

function postRequest(body, origin = "https://boginfactory.com") {
  return new Request("https://grace-waitlist.workers.dev/", {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: origin },
    body: JSON.stringify(body),
  });
}

// Capture Resend/PostHog calls by stubbing global fetch for the duration of a test.
function withFetchStub(fn) {
  const calls = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, opts) => {
    calls.push({ url, opts });
    return new Response(JSON.stringify({ id: "email_123" }), { status: 200 });
  };
  return Promise.resolve(fn(calls)).finally(() => {
    globalThis.fetch = original;
  });
}

// ── Tests ────────────────────────────────────────────────────────────────────

test("OPTIONS preflight returns CORS headers", async () => {
  const env = makeEnv();
  const req = new Request("https://x/", {
    method: "OPTIONS",
    headers: { Origin: "https://boginfactory.com" },
  });
  const res = await handleRequest(req, env);
  assert.equal(res.status, 204);
  assert.equal(
    res.headers.get("Access-Control-Allow-Origin"),
    "https://boginfactory.com"
  );
});

test("valid signup is stored and emails are sent", async () => {
  await withFetchStub(async (calls) => {
    const env = makeEnv();
    const res = await handleRequest(
      postRequest({
        email: "friend@example.com",
        name: "Pat",
        country: "USA",
        phone: "555-1234",
        instagram: "@pat",
        smsConsent: true,
        referrer: "abc123xy",
        myCode: "newcode1",
        source: "watch",
      }),
      env
    );
    assert.equal(res.status, 200);
    assert.equal(env.DB.inserted.length, 1);
    // instagram + sms_consent + referrer + my_code + source persisted (order matches INSERT)
    assert.equal(env.DB.inserted[0][5], "@pat");
    assert.equal(env.DB.inserted[0][6], "yes");
    assert.equal(env.DB.inserted[0][7], "abc123xy");
    assert.equal(env.DB.inserted[0][8], "newcode1");
    assert.equal(env.DB.inserted[0][9], "watch");
    // confirmation + admin email = 2 Resend calls
    assert.equal(calls.length, 2);
    assert.match(calls[0].url, /api\.resend\.com/);
    const sent = JSON.parse(calls[0].opts.body);
    assert.equal(sent.to, "friend@example.com");
    assert.match(sent.html, /ref=newcode1/);
  });
});

test("submission with no email sends only admin email", async () => {
  await withFetchStub(async (calls) => {
    const env = makeEnv();
    const res = await handleRequest(postRequest({ name: "Anon" }), env);
    assert.equal(res.status, 200);
    assert.equal(env.DB.inserted.length, 1);
    assert.equal(calls.length, 1); // admin only
    const sent = JSON.parse(calls[0].opts.body);
    assert.equal(sent.to, "gracesholybell@boginfactory.com");
  });
});

test("invalid email is rejected", async () => {
  const env = makeEnv();
  const res = await handleRequest(postRequest({ email: "not-an-email" }), env);
  assert.equal(res.status, 400);
  assert.equal(env.DB.inserted.length, 0);
});

test("completely empty submission is rejected", async () => {
  const env = makeEnv();
  const res = await handleRequest(postRequest({ country: "USA" }), env);
  assert.equal(res.status, 400);
  assert.equal(env.DB.inserted.length, 0);
});

test("honeypot submissions are silently dropped", async () => {
  await withFetchStub(async (calls) => {
    const env = makeEnv();
    const res = await handleRequest(
      postRequest({ email: "bot@spam.com", website: "http://spam" }),
      env
    );
    assert.equal(res.status, 200);
    assert.equal(env.DB.inserted.length, 0);
    assert.equal(calls.length, 0);
  });
});

test("malformed JSON returns 400", async () => {
  const env = makeEnv();
  const req = new Request("https://x/", {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: "https://boginfactory.com" },
    body: "{not json",
  });
  const res = await handleRequest(req, env);
  assert.equal(res.status, 400);
});

test("CSV export requires a valid token", async () => {
  const env = makeEnv();
  const bad = await handleRequest(
    new Request("https://x/export.csv?token=wrong", { method: "GET" }),
    env
  );
  assert.equal(bad.status, 401);
});

test("CSV export returns stored rows with valid token", async () => {
  const env = makeEnv();
  // seed a row
  await handleRequest(postRequest({ email: "a@b.com", name: "A,B" }), env);
  const res = await handleRequest(
    new Request("https://x/export.csv?token=secret-token", { method: "GET" }),
    env
  );
  assert.equal(res.status, 200);
  const text = await res.text();
  assert.match(text, /created_at,email,name,country,phone,instagram,sms_consent,referrer,my_code,source/);
  assert.match(text, /a@b\.com/);
  assert.match(text, /"A,B"/); // comma-containing cell is quoted
});

// ── Referral click tracking (GET /r/<code>) ─────────────────────────────────

function getRequest(path, { userAgent, cf } = {}) {
  const headers = new Headers();
  if (userAgent) headers.set("User-Agent", userAgent);
  return {
    method: "GET",
    url: "https://grace-waitlist.workers.dev" + path,
    headers,
    cf: cf || {},
  };
}

const IPHONE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15";
const ANDROID_UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36";
const BOT_UA = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)";

test("valid click logs to D1 and redirects to the waitlist page by default", async () => {
  const env = makeEnv();
  const ctx = makeCtx();
  const res = await handleRequest(
    getRequest("/r/abc12345?src=phone", { userAgent: IPHONE_UA }),
    env,
    ctx
  );
  await ctx.flush();
  assert.equal(res.status, 302);
  assert.equal(
    res.headers.get("Location"),
    "https://boginfactory.com/grace-waitlist.html?ref=abc12345&src=phone"
  );
  assert.equal(res.headers.get("Cache-Control"), "no-store");
  assert.equal(env.DB.clicksInserted.length, 1);
  const [, code, source, device, country] = env.DB.clicksInserted[0];
  assert.equal(code, "abc12345");
  assert.equal(source, "phone");
  assert.equal(device, "ios");
  assert.equal(country, "");
});

test("android and bot user agents classify correctly", async () => {
  const env = makeEnv();
  const ctx = makeCtx();
  await handleRequest(getRequest("/r/abc12345", { userAgent: ANDROID_UA }), env, ctx);
  await handleRequest(getRequest("/r/abc12345", { userAgent: BOT_UA }), env, ctx);
  await ctx.flush();
  assert.equal(env.DB.clicksInserted[0][3], "android");
  assert.equal(env.DB.clicksInserted[1][3], "bot");
});

test("invalid referral code still redirects without logging a click", async () => {
  const env = makeEnv();
  const ctx = makeCtx();
  const res = await handleRequest(getRequest("/r/AB"), env, ctx);
  await ctx.flush();
  assert.equal(res.status, 302);
  assert.equal(env.DB.clicksInserted.length, 0);
});

test("REDIRECT_URL env var flips the destination to the App Store, verbatim", async () => {
  const env = makeEnv({ REDIRECT_URL: "https://apps.apple.com/app/id123456789" });
  const ctx = makeCtx();
  const res = await handleRequest(
    getRequest("/r/abc12345?src=watch", { userAgent: IPHONE_UA }),
    env,
    ctx
  );
  await ctx.flush();
  assert.equal(res.headers.get("Location"), "https://apps.apple.com/app/id123456789");
  assert.equal(env.DB.clicksInserted.length, 1); // click is still logged
});

test("bot clicks are logged in D1 but do not fire a PostHog event", async () => {
  await withFetchStub(async (calls) => {
    const env = makeEnv({ POSTHOG_API_KEY: "phc_test" });
    const ctx = makeCtx();
    await handleRequest(getRequest("/r/abc12345", { userAgent: BOT_UA }), env, ctx);
    await ctx.flush();
    assert.equal(env.DB.clicksInserted.length, 1);
    assert.equal(env.DB.clicksInserted[0][3], "bot");
    assert.equal(calls.length, 0);
  });
});

test("PostHog capture fires with correct event/properties on a referral click", async () => {
  await withFetchStub(async (calls) => {
    const env = makeEnv({ POSTHOG_API_KEY: "phc_test" });
    const ctx = makeCtx();
    await handleRequest(
      getRequest("/r/abc12345?src=phone", { userAgent: IPHONE_UA, cf: { country: "US" } }),
      env,
      ctx
    );
    await ctx.flush();
    assert.equal(calls.length, 1);
    assert.match(calls[0].url, /eu\.i\.posthog\.com/);
    const sent = JSON.parse(calls[0].opts.body);
    assert.equal(sent.api_key, "phc_test");
    assert.equal(sent.event, "referral_link_clicked");
    assert.equal(sent.distinct_id, "ref:abc12345");
    assert.equal(sent.properties.ref_code, "abc12345");
    assert.equal(sent.properties.source, "phone");
    assert.equal(sent.properties.device, "ios");
    assert.equal(sent.properties.country, "US");
    assert.equal(sent.properties.destination, "waitlist");
    assert.equal(sent.properties.$process_person_profile, false);
  });
});

test("missing POSTHOG_API_KEY skips capture without affecting the redirect", async () => {
  await withFetchStub(async (calls) => {
    const env = makeEnv(); // no POSTHOG_API_KEY
    const ctx = makeCtx();
    const res = await handleRequest(getRequest("/r/abc12345", { userAgent: IPHONE_UA }), env, ctx);
    await ctx.flush();
    assert.equal(res.status, 302);
    assert.equal(calls.length, 0);
  });
});

test("PostHog capture failure never affects the redirect response", async () => {
  const env = makeEnv({ POSTHOG_API_KEY: "phc_test" });
  const ctx = makeCtx();
  const original = globalThis.fetch;
  globalThis.fetch = async () => {
    throw new Error("network down");
  };
  try {
    const res = await handleRequest(getRequest("/r/abc12345", { userAgent: IPHONE_UA }), env, ctx);
    assert.equal(res.status, 302);
    await ctx.flush(); // must not throw
  } finally {
    globalThis.fetch = original;
  }
});

test("D1 insert failure for a click still redirects", async () => {
  const env = makeEnv();
  env.DB = {
    prepare() {
      return {
        bind() {
          return this;
        },
        async run() {
          throw new Error("D1 unavailable");
        },
      };
    },
  };
  const ctx = makeCtx();
  const res = await handleRequest(getRequest("/r/abc12345", { userAgent: IPHONE_UA }), env, ctx);
  await ctx.flush(); // must not throw
  assert.equal(res.status, 302);
});

test("export-clicks.csv requires a valid token", async () => {
  const env = makeEnv();
  const res = await handleRequest(
    new Request("https://x/export-clicks.csv?token=wrong", { method: "GET" }),
    env
  );
  assert.equal(res.status, 401);
});

test("export-clicks.csv returns stored click rows with valid token", async () => {
  const env = makeEnv();
  const ctx = makeCtx();
  await handleRequest(getRequest("/r/abc12345?src=phone", { userAgent: IPHONE_UA }), env, ctx);
  await ctx.flush();
  const res = await handleRequest(
    new Request("https://x/export-clicks.csv?token=secret-token", { method: "GET" }),
    env
  );
  assert.equal(res.status, 200);
  const text = await res.text();
  assert.match(text, /created_at,code,source,device,country/);
  assert.match(text, /abc12345,phone,ios/);
});

// ── PostHog capture on signup (POST /) ──────────────────────────────────────

test("waitlist_signup capture fires with no PII in properties", async () => {
  await withFetchStub(async (calls) => {
    const env = makeEnv({ POSTHOG_API_KEY: "phc_test" });
    const ctx = makeCtx();
    await handleRequest(
      postRequest({
        email: "friend@example.com",
        name: "Pat",
        referrer: "abc123xy",
        myCode: "newcode1",
        source: "watch",
      }),
      env,
      ctx
    );
    await ctx.flush();
    // confirmation + admin emails (2) + PostHog capture (1)
    assert.equal(calls.length, 3);
    const posthogCall = calls.find((c) => /posthog/.test(c.url));
    const sent = JSON.parse(posthogCall.opts.body);
    assert.equal(sent.event, "waitlist_signup");
    assert.equal(sent.distinct_id, "ref:abc123xy");
    assert.equal(sent.properties.ref_code, "abc123xy");
    assert.equal(sent.properties.new_code, "newcode1");
    assert.equal(sent.properties.source, "watch");
    assert.equal(sent.properties.has_email, true);
    assert.equal(sent.properties.$process_person_profile, false);
    // no PII leaks into the event payload
    const keys = Object.keys(sent.properties);
    for (const pii of ["email", "name", "phone", "instagram", "country"]) {
      assert.ok(!keys.includes(pii), `properties must not include "${pii}"`);
    }
    assert.doesNotMatch(JSON.stringify(sent.properties), /friend@example\.com/);
    assert.doesNotMatch(JSON.stringify(sent.properties), /Pat/);
  });
});

test("waitlist_signup capture uses 'organic' distinct_id when there is no referrer", async () => {
  await withFetchStub(async (calls) => {
    const env = makeEnv({ POSTHOG_API_KEY: "phc_test" });
    const ctx = makeCtx();
    await handleRequest(postRequest({ name: "Anon" }), env, ctx);
    await ctx.flush();
    const posthogCall = calls.find((c) => /posthog/.test(c.url));
    const sent = JSON.parse(posthogCall.opts.body);
    assert.equal(sent.distinct_id, "ref:organic");
    assert.equal(sent.properties.ref_code, "");
    assert.equal(sent.properties.has_email, false);
  });
});
