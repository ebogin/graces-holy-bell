# Welcome Message — Remote Config

## What this is

The idle-screen welcome text (the LCD-green line above "SLIDE TO BEGIN") is
served from the `grace-waitlist` Cloudflare Worker instead of being hard-coded
in the app. Changing it — the copy, its alignment/size/color, adding an image,
adding a tap-through detail sheet, or targeting it to only some users — needs
**no app build and no App Store review**. Just a `curl` command.

The app fetches this anonymously (no install ID, no device identifiers) on
launch and on every foreground, caches the result, and falls back to a bundled
default message if it's never reached the network. There is no remote code —
only declarative content (text/image/link "blocks") that the app already knows
how to render, per Apple's guideline against downloading executable code. New
*behaviors* need an app update; new *content* does not.

## How to update — the exact command

```bash
curl -X POST https://grace-waitlist.grace-waitlist.workers.dev/admin/app-config \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @welcome.json
```

Where `welcome.json` is a file containing `{"welcome": { ... }}` — see the
schema and examples below.

- **`grace-waitlist.grace-waitlist.workers.dev`**: the Worker's live
  `*.workers.dev` hostname (same one the CSV export URLs in
  `waitlist/SETUP.md` use, once filled in). Admin writes intentionally stay
  off the public `boginfactory.com` domain.
- **`$ADMIN_TOKEN`**: the same Cloudflare Worker secret already used for the
  waitlist CSV exports (`waitlist/SETUP.md`). Set it once with
  `npx wrangler secret put ADMIN_TOKEN` from `waitlist/`; retrieve/store it
  locally yourself (e.g. in a password manager or local `.env` you don't
  commit) — Cloudflare does not let you read a secret's value back out.

## How to verify

```bash
curl https://boginfactory.com/app-config
```

This should echo back what you just posted, parsed (not double-encoded)
under the `welcome` key. Propagation:

- **Edge cache**: up to 5 minutes (`Cache-Control: public, max-age=300` on the
  public `GET /app-config`).
- **Client throttle**: the app won't re-fetch more than once per 15 minutes
  per device.
- **Visibility**: the new message appears the next time the app is launched or
  brought to the foreground *after* both of the above have elapsed. Force it
  sooner by force-quitting and relaunching the app well after the 5-minute
  edge cache window.

## Full schema reference

The value stored under the `welcome` key, and returned by `GET /app-config`:

```json
{
  "welcome": {
    "version": 1,
    "messages": [
      {
        "id": "free-form-string-for-your-own-logging",
        "audience": "all",
        "blocks": [ /* see Block types below */ ],
        "detail": { "title": "...", "blocks": [ /* ... */ ] }
      }
    ]
  }
}
```

### Selection rule

The app walks `messages` **in order** and displays the **first** one whose
`audience` it satisfies. Always end the list with an `"audience": "all"`
message as a catch-all. If nothing matches (or the whole fetch/parse fails),
the app shows its bundled default line. `id` is free-form, used only for your
own logging/debugging — the app doesn't interpret it.

### Audience values (v1)

| value                 | matches when…                                    |
|-----------------------|---------------------------------------------------|
| `all`                 | always                                             |
| `watch_not_installed` | this install has no reachable companion Watch app  |
| `watch_installed`     | this install has a reachable companion Watch app   |

An audience string the app doesn't recognize matches **nothing** — the message
is skipped, not shown by accident. This is what lets you add new audience
types later without breaking old app versions still in the wild.

### Block types (v1)

Every field except the ones marked required is optional with the listed
default. **Unknown block types and unknown fields inside a known block are
silently ignored** — never make content stricter than this or old app
versions will fail to render new content gracefully.

- **`text`** — `value` (required, plain string, newlines honored, trimmed and
  clamped to 1000 characters).
  - `align`: `"leading"` (default) | `"center"` | `"trailing"`
  - `size`: `"small"` | `"body"` (default) | `"large"`
  - `color`: `"dark"` (default) | `"mid"` — these are the app's own LCD
    palette tokens; there is no way to send an arbitrary hex color, by design.
- **`image`** — `url` (required, **must be `https://`** or the block is
  dropped), `caption` (optional, small text underneath). Rendered aspect-fit.
  Pre-style the image yourself for the LCD look (green background, pixel
  aesthetic) — the app does not filter or recolor it.
- **`link`** — `label` (required), `destination` (required):
  - `"detail"` — opens this message's `detail` sheet (see below). If the
    message has no `detail` object, the link renders as inert/nothing.
  - any `https://` URL — opens in the system browser sheet.
  - anything else (a custom scheme, a non-https URL) is dropped.

### The `detail` object (optional, per message)

`title` (string) + `blocks` (same schema as above; `link` blocks inside
`detail` are ignored). Presented as a full-height sheet when a `"destination":
"detail"` link is tapped. Use this for anything too long for the idle screen's
small welcome area — e.g. a multi-step diagram.

## Two complete copy-paste examples

### (a) Simple text-only change

```bash
cat > welcome.json <<'EOF'
{
  "welcome": {
    "version": 1,
    "messages": [
      {
        "id": "lent-2027",
        "audience": "all",
        "blocks": [
          { "type": "text", "value": "Blessed Lent — may this Bell help you keep vigil." }
        ]
      }
    ]
  }
}
EOF

curl -X POST https://grace-waitlist.grace-waitlist.workers.dev/admin/app-config \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @welcome.json
```

### (b) Watch-install targeting, with a detail sheet and image

```bash
cat > welcome.json <<'EOF'
{
  "welcome": {
    "version": 1,
    "messages": [
      {
        "id": "watch-install-2026-07",
        "audience": "watch_not_installed",
        "blocks": [
          { "type": "text", "value": "GET GRACE ON YOUR WRIST", "align": "center", "size": "large" },
          { "type": "text", "value": "Prayers sync from your Apple Watch automatically." },
          { "type": "link", "label": "HOW TO INSTALL", "destination": "detail" }
        ],
        "detail": {
          "title": "INSTALL ON APPLE WATCH",
          "blocks": [
            { "type": "image", "url": "https://boginfactory.com/img/watch-install.png", "caption": "Watch app -> Available Apps -> Install" },
            { "type": "text", "value": "1. Open the Watch app on your iPhone.\n2. Scroll to Available Apps.\n3. Tap Install next to Grace's Holy Bell." }
          ]
        }
      },
      {
        "id": "default-2026-07",
        "audience": "all",
        "blocks": [
          { "type": "text", "value": "Welcome to your favorite app to time prayer duration." }
        ]
      }
    ]
  }
}
EOF

curl -X POST https://grace-waitlist.grace-waitlist.workers.dev/admin/app-config \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @welcome.json
```

Note the `watch_not_installed` message comes first and the `all` message is
the catch-all after it — order matters (see Selection rule above).

## Content guidelines

- Keep the idle-screen `blocks` text under ~120 characters total — it's
  rendered in the pixel font (Press Start 2P) in a small fixed area above the
  "SLIDE TO BEGIN" blinker. Longer content belongs in `detail`.
- Images must be pre-styled for the LCD look (green background, no drop
  shadows/gloss) before you host them — the app renders them as-is.
- Host images under `docs/` in this repo (served at `boginfactory.com/...`).
  **Reminder:** `docs/` is mirrored to the separate
  `ebogin/Boginfactory-Landing-Page` repo — after adding an image there, mirror
  that change via `gh` the same way other `docs/` edits are.
- Always end `messages` with an `"audience": "all"` entry.
- Unknown fields and unknown block/audience types are ignored by the app —
  you can add new content shapes speculatively; old app versions simply won't
  render the parts they don't understand yet, not crash or show nothing at all
  (as long as an earlier message or the trailing `all` message still matches).

## How to roll back

Re-POST the single default message, verbatim:

```bash
curl -X POST https://grace-waitlist.grace-waitlist.workers.dev/admin/app-config \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"welcome":{"version":1,"messages":[{"id":"default","audience":"all","blocks":[{"type":"text","value":"Welcome to your favorite app to time prayer duration."}]}]}}'
```

This is also the exact seed payload used the first time this feature was
deployed.
