---
name: grace-welcome
description: >-
  Update Grace's Holy Bell's remote idle-screen welcome message — the LCD-green line above
  "SLIDE TO BEGIN". Use when the user says "change/update the welcome message", "change the
  idle-screen text", "change what the app shows above SLIDE TO BEGIN", "target a message to
  Watch users", "add a welcome image/detail sheet", or "roll back the welcome message". Edits
  live content via the grace-waitlist Cloudflare Worker — no app build, no App Store review.
---

# Update the app's welcome message (remote config)

The idle-screen welcome text is served by the **grace-waitlist** Cloudflare Worker, not baked
into the app. Changing the copy, its alignment/size/color, adding an image, adding a tap-through
detail sheet, or targeting it to a subset of users needs **no app build and no App Store review**
— just a token-protected POST. The app fetches it anonymously on launch/foreground and falls back
to a bundled default if it never reaches the network.

Full protocol + schema of record: `WELCOME_MESSAGE.md` at the graces-holy-bell repo root. This
skill is the operational wrapper around it.

This skill exists in two places so it's available everywhere:
- **`~/.claude/skills/grace-welcome/`** — global install on the local machine (available in every
  local conversation, on any branch/worktree).
- **`.claude/skills/grace-welcome/` in the repo** — so it's also available in Claude **cloud
  containers** (the phone/web app), which clone the repo and don't see the local global install.

Keep the two copies in sync. **Run it from inside the graces-holy-bell repo** (any branch/worktree).

## Do it with the helper script

The helper script `grace-welcome.sh` sits in **this skill's own directory** — invoke it by its full
path there (`~/.claude/skills/grace-welcome/grace-welcome.sh` for the global install, or
`<repo>/.claude/skills/grace-welcome/grace-welcome.sh` in a repo/cloud checkout). It resolves the
token, validates the payload against the app's tolerant schema, publishes, and echoes back exactly
what got stored. Use it rather than hand-writing the `curl` — it catches the mistakes that silently
break a message (missing catch-all, non-https image, oversize body). Examples below use the global
path; substitute the repo path when running in a cloud container.

```bash
grace-welcome.sh verify                  # print what's live right now
grace-welcome.sh validate welcome.json   # schema-check a draft, no network
grace-welcome.sh post welcome.json --yes # publish (see the confirm rule below)
grace-welcome.sh rollback --yes          # restore the single default catch-all message
```

## Workflow

1. **See what's live** (context for any change):
   ```bash
   bash ~/.claude/skills/grace-welcome/grace-welcome.sh verify
   ```
2. **Draft the payload** to a `welcome.json` (scratchpad is fine — it doesn't belong in the repo).
   Start from a template in [`examples/`](examples/): `simple-text.json` (text-only) or
   `watch-targeting.json` (audience targeting + detail sheet + image). Craft the copy with the
   user; keep each idle screen under ~120 characters (it's a small pixel-font area — long copy
   goes in a `detail` sheet).
3. **Validate** and read the warnings:
   ```bash
   bash ~/.claude/skills/grace-welcome/grace-welcome.sh validate welcome.json
   ```
4. **Confirm with the user, then publish.** Publishing changes what *every* app user sees — it's
   outward-facing. Show the user the exact payload and get an explicit yes, **then** pass `--yes`:
   ```bash
   bash ~/.claude/skills/grace-welcome/grace-welcome.sh post welcome.json --yes
   ```
   The POST response echoes the stored value back (authoritative, uncached) — that's your
   immediate confirmation. Without `--yes` and without a TTY the script refuses rather than
   publishing unconfirmed.
5. **Note propagation** when telling the user it's live: the public `GET /app-config` is
   edge-cached up to 5 min, and the app self-throttles refetch to once / 15 min / device. New copy
   appears on the next launch/foreground after both elapse; force-quit + relaunch (well after 5 min)
   to see it sooner.

## Guardrails — read before publishing

- **Publishing is outward-facing.** Never `post`/`rollback` with `--yes` until the user has
  approved the exact content in chat. The script won't publish non-interactively without `--yes`.
- **Always end `messages` with an `"audience": "all"` catch-all.** The app shows the first message
  whose audience matches; anyone matching nothing (including old app versions that don't know a new
  audience type) falls back to the app's bundled default. `validate` warns if the last message
  isn't `all`. Order matters — put targeted messages *before* the catch-all.
- **Audience values (v1):** `all`, `watch_installed`, `watch_not_installed`. An unrecognized
  audience matches **nothing** (this is what makes new audience types safe to add later) — but it
  also means a typo silently hides your message. `validate` flags unknown audiences.
- **Images must be `https://`, pre-styled, and hosted under `docs/`.** The app renders images
  as-is (no recolor/filter), so pre-style for the LCD look (green background, pixel aesthetic, no
  gloss/shadow). A non-https `url` is dropped by the app. Host under `docs/` (served at
  `boginfactory.com/...`).
  - ⚠️ **`docs/` is mirrored to a separate repo.** After adding an image under `docs/`, mirror that
    file into the root of **`ebogin/Boginfactory-Landing-Page`** via `gh` — the same mirror step
    used for every other `docs/` change. `boginfactory.com` is served from that repo, **not** this
    one; an image only in this repo's `docs/` will 404 and the block will render blank.
- **Unknown block types / fields are ignored by the app, by design.** You can add new content
  shapes speculatively — old app versions render the parts they understand and skip the rest (as
  long as a matching message or the trailing `all` still renders *something*). Don't rely on a new
  *behavior*; only new *content* works without an app update.
- **Size cap:** the Worker rejects any welcome value over 32 KiB. `validate` catches this.

## Schema (condensed)

```json
{ "welcome": { "version": 1, "messages": [
  { "id": "free-form-log-string", "audience": "all",
    "blocks": [ /* text | image | link */ ],
    "detail": { "title": "…", "blocks": [ /* text | image; link ignored here */ ] } }
] } }
```

Block types (every field but the required one is optional; unknown fields ignored):
- **`text`** — `value` (required, ≤1000 chars, newlines honored). `align`: `leading`(default)|`center`|`trailing`. `size`: `small`|`body`(default)|`large`. `color`: `dark`(default)|`mid` (LCD palette tokens only — no arbitrary hex).
- **`image`** — `url` (required, must be `https://`), `caption` (optional small text). Aspect-fit.
- **`link`** — `label` + `destination` (required). `destination`: `"detail"` (opens this message's
  `detail` sheet; inert if there's no `detail`) or any `https://` URL (system browser). Anything
  else is dropped.

`detail` (optional per message): `title` + `blocks` (same schema; `link` blocks ignored inside it).
Use it for content too long for the small idle area.

## Rollback

Restore the original default line (also the first-deploy seed payload):

```bash
bash ~/.claude/skills/grace-welcome/grace-welcome.sh rollback --yes   # after user confirms
```
This posts: `{"welcome":{"version":1,"messages":[{"id":"default","audience":"all","blocks":[{"type":"text","value":"Welcome to your favorite app to time prayer duration."}]}]}}`

## The ADMIN_TOKEN

Same Worker secret as the waitlist CSV exports (`waitlist/SETUP.md`) — it authorizes changing the
welcome message. Cloudflare won't let you read a secret back out, so it must be available locally.
The script resolves it in this order:

1. `$ADMIN_TOKEN` in the environment
2. **`~/.config/grace-welcome/config.env`** — a line `ADMIN_TOKEN=…` (canonical; global, so it works
   from any directory, branch, or **git worktree**)
3. `<repo>/waitlist/.dev.vars` — repo-local. ⚠️ Untracked, so it **does not exist inside git
   worktrees** (`.claude/worktrees/*`); rely on (2) there, not this.
4. `<repo>/.env`, `<repo>/waitlist/.env`

Run the **`doctor`** command to confirm the token resolves from the current directory (it prints the
source, never the value). If nothing has it, the script prints setup instructions and exits. It
never hardcodes or commits the token. **Do not** paste the token into a committed file — put it in
`~/.config/grace-welcome/config.env` (mode 600). If the secret was never set on the Worker, set it
once from `waitlist/`: `npx wrangler secret put ADMIN_TOKEN`.

### In a Claude cloud container

The local token files (`~/.config/grace-welcome/config.env`, `waitlist/.dev.vars`) **do not exist**
in a cloud container — it's a fresh checkout. So only source (1), the `$ADMIN_TOKEN` **environment
variable**, is available there. Set `ADMIN_TOKEN` as an environment variable / secret in the cloud
container's environment settings (in the Claude app), and `post`/`rollback` will work. `validate`,
`verify`, and drafting need no token. Never commit the token to the repo.
