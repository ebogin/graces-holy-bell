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
  return {
    inserted,
    rows,
    prepare(sql) {
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
              sms_consent: this._args[5],
              referrer: this._args[6],
              my_code: this._args[7],
              source: this._args[8],
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

function postRequest(body, origin = "https://boginfactory.com") {
  return new Request("https://grace-waitlist.workers.dev/", {
    method: "POST",
    headers: { "Content-Type": "application/json", Origin: origin },
    body: JSON.stringify(body),
  });
}

// Capture Resend calls by stubbing global fetch for the duration of a test.
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
        smsConsent: true,
        referrer: "abc123xy",
        myCode: "newcode1",
        source: "watch",
      }),
      env
    );
    assert.equal(res.status, 200);
    assert.equal(env.DB.inserted.length, 1);
    // sms_consent + referrer + my_code + source persisted (order matches INSERT)
    assert.equal(env.DB.inserted[0][5], "yes");
    assert.equal(env.DB.inserted[0][6], "abc123xy");
    assert.equal(env.DB.inserted[0][7], "newcode1");
    assert.equal(env.DB.inserted[0][8], "watch");
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
  assert.match(text, /created_at,email,name,country,phone,sms_consent,referrer,my_code,source/);
  assert.match(text, /a@b\.com/);
  assert.match(text, /"A,B"/); // comma-containing cell is quoted
});
