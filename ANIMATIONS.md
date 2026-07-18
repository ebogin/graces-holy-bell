# Prayer Actions — Remote Config

## What this is

After each PRAY swipe of a session, the praying figure performs a short
**action** — the 1st swipe plays action #1, the 2nd plays #2, and so on —
before returning to praying. That ordered sequence of actions (and how long
each plays) is served from the `grace-waitlist` Cloudflare Worker under the
`animations` key of `/app-config`, the *same* endpoint that already serves the
idle-screen welcome message (see [WELCOME_MESSAGE.md](WELCOME_MESSAGE.md)).

Changing the sequence — reordering, adding actions, retiming them — needs **no
app build and no App Store review**. Just a `curl`. There is **no Worker change
either**: the `app_config` store is schema-agnostic (any top-level key is
stored and echoed back verbatim), so `animations` rides alongside `welcome`
with zero server code.

Both the **iPhone and the Apple Watch** fetch this anonymously (no install ID,
no device identifiers) on launch and on every foreground, cache the result, and
fall back to a **bundled default** sequence if the network is never reached.
There is no remote code — only declarative content the app already knows how to
interpret, per Apple's guideline against downloading executable code. New
action *fields* need an app update; new action *sequences* do not.

> **SCAFFOLDING STATUS (2026-07):** the per-action *artwork* is not built yet.
> Each action currently renders a placeholder — a large "#N" plus a small
> animated icon — in the figure's on-screen slot. The remote-config plumbing,
> index selection, timing, and Watch parity described here are all live and
> testable now. See [HANDOFF-prayer-animations.md](HANDOFF-prayer-animations.md)
> for building the real animations.

## How to update — the exact command

```bash
curl -X POST https://grace-waitlist.grace-waitlist.workers.dev/admin/app-config \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @animations.json
```

Where `animations.json` contains `{"animations": { ... }}` — see the schema and
examples below.

- **`grace-waitlist.grace-waitlist.workers.dev`**: the Worker's live
  `*.workers.dev` admin hostname (admin writes intentionally stay off the
  public `boginfactory.com` domain).
- **`$ADMIN_TOKEN`**: the same Cloudflare Worker secret used for the waitlist
  CSV exports and the welcome message. It is a *shared* config write — posting
  `{"animations": …}` updates only that key and leaves `welcome` untouched, and
  vice versa. To update both at once, POST one object with both keys.
- **Size limit**: 32 KB for the serialized `animations` value (enforced by the
  Worker). A text-only manifest is a few hundred bytes; this only matters if you
  ever inline data.

## How to verify

```bash
curl https://boginfactory.com/app-config
```

Echoes back what you posted, parsed (not double-encoded), under the
`animations` key (next to `welcome`). Propagation:

- **Edge cache**: up to 5 minutes (`Cache-Control: public, max-age=300`).
- **Client throttle**: each device re-fetches at most once per 15 minutes.
- **Visibility**: the new sequence takes effect the next time the app (phone or
  watch) is launched or foregrounded *after* both windows elapse. Force it
  sooner by force-quitting and relaunching well after the 5-minute edge window.

## Full schema reference

The value stored under the `animations` key, and returned by `GET /app-config`:

```json
{
  "animations": {
    "version": 1,
    "defaultDurationSeconds": 5,
    "actions": [
      { "id": "kneel",        "durationSeconds": 5, "label": "#1" },
      { "id": "walk-to-door", "durationSeconds": 6, "label": "#2" },
      { "id": "exit-house",   "durationSeconds": 5, "label": "#3" }
    ]
  }
}
```

### Selection rule

The app plays `actions[N-1]` for the **N-th** PRAY of a session (1-based: the
first swipe → the first action). Once the session's prayer count passes
`actions.length`, no action plays and the figure simply keeps praying. A
session reset (Clear Log) starts the sequence over at #1.

This is a deliberately finite "story" model (e.g. *kneel → walk to door → step
outside*). To make it loop or hold on the last action instead, that's a one-line
change in the app (`PrayerActionsConfig.action(forPrayerIndex:)`) — content
alone can't change the selection strategy.

### Fields

Every field except the ones noted is optional with the listed default.
**Unknown fields and unknown keys are silently ignored** — never make content
stricter than this, or older app versions won't render newer content
gracefully.

- **`version`** (int, optional) — informational; for future migrations.
- **`defaultDurationSeconds`** (number, optional, default `5`) — duration used
  for any action that omits its own `durationSeconds`.
- **`actions`** (array, optional, default empty) — the ordered sequence. A
  missing or malformed `actions` list degrades to "no actions" (figure keeps
  praying) rather than failing the whole config. Each entry:
  - **`id`** (string, optional, default `"action-<index>"`) — a **stable
    identifier** the real animation keys its artwork on (e.g. `"kneel"`). Pick
    ids deliberately and keep them stable; renaming an id is like renaming an
    asset. This is the field the animation implementation cares about most.
  - **`durationSeconds`** (number, optional) — how long the action plays before
    the figure returns to praying. Falls back to `defaultDurationSeconds`, then
    to `5`. Clamped to a `0.1` s minimum.
  - **`label`** (string, optional, default `"#<index>"`) — placeholder caption
    the current scaffolding shows large. The real animation ignores it; you can
    drop it once the artwork exists.

## Copy-paste example — the three-step story

```bash
cat > animations.json <<'EOF'
{
  "animations": {
    "version": 1,
    "defaultDurationSeconds": 5,
    "actions": [
      { "id": "kneel",        "durationSeconds": 5 },
      { "id": "walk-to-door", "durationSeconds": 6 },
      { "id": "exit-house",   "durationSeconds": 5 }
    ]
  }
}
EOF

curl -X POST https://grace-waitlist.grace-waitlist.workers.dev/admin/app-config \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d @animations.json
```

Until the real artwork for `kneel` / `walk-to-door` / `exit-house` ships, these
render as the placeholders **#1 / #2 / #3** (each also showing its `id`), for
5 / 6 / 5 seconds respectively.

## Feature flag

`FeatureFlags.prayerActionsEnabled` (in `Shared/FeatureFlags.swift`) gates
**both** the iPhone and the Watch: off → no animations fetch on either
platform, and the figure just keeps praying (prior behavior). Currently
**`false`** on `main` — the feature is still in development (real artwork,
change pipeline, admin UI are pending); see
[HANDOFF-prayer-animations.md](HANDOFF-prayer-animations.md) for the full
picture and where this code lives on origin.

## How to roll back

Re-POST an empty sequence (figure just prays), or the bundled placeholder set:

```bash
# Disable all actions (figure keeps praying):
curl -X POST https://grace-waitlist.grace-waitlist.workers.dev/admin/app-config \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"animations":{"version":1,"actions":[]}}'
```

Note the app's **bundled default** (5 generic placeholder actions, 5 s each) is
what ships in the binary and is used until a remote fetch lands — rolling the
remote value back to `[]` disables actions for devices that *have* fetched;
devices that never reach the network still show the bundled default. To change
the bundled default itself, edit `PrayerActionsConfig.bundledDefault` (needs a
build).
