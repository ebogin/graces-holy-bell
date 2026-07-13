# Handoff — Publish Grace's Holy Bell landing page to production

**For:** an agent/developer with normal shell + network + GitHub access (NOT a sandbox).
**Goal:** commit the new marketing landing page to the source repo, then mirror it to
the live-site repo and push, so it goes live at
`https://boginfactory.com/grace-holy-bell.html`.

## Why this handoff exists

The page is fully built and all files are on disk, but the previous session ran in a
sandbox that (a) had **no network route to GitHub** and (b) **could not write to `.git`**.
So nothing is committed or pushed yet. You just need to run the git steps below.

## Repo layout (important — TWO repos)

- **Source repo:** `ebogin/graces-holy-bell` — local at `~/Developer/graces-holy-bell`.
  The page source lives under `docs/` (source-of-truth copy only; editing `docs/` does
  NOT change the live site).
- **Production repo:** `ebogin/Boginfactory-Landing-Page` — this is what serves
  `boginfactory.com`. Files live at the **repo root** (not under `docs/`). Publishing =
  copying the files into this repo's root and pushing. Same mirror pattern already used
  for `grace-waitlist.html` and `graces-privacy-policy.html`.

## Files to publish (all in `~/Developer/graces-holy-bell/docs/`)

- `grace-holy-bell.html` — the page (new)
- `grace-phone-active.jpg` — iPhone screenshot (new)
- `grace-watch-active.jpg` — Apple Watch timer screenshot (new)
- `grace-watch-log.jpg` — Apple Watch log screenshot (new)
- `pray-sprite-strip.png` — 4-frame sprite sheet for the animated praying figure (new)

The page's footer links to `grace-waitlist.html` and `graces-privacy-policy.html`, which
already exist in the production repo root — no need to touch them.

## Known issue to clear first

A stale empty `.git/index.lock` was left in `~/Developer/graces-holy-bell` by the
sandbox's failed commit attempt. Remove it before committing:

```bash
rm -f ~/Developer/graces-holy-bell/.git/index.lock
```

## Step 1 — commit the source repo

```bash
cd ~/Developer/graces-holy-bell
rm -f .git/index.lock
git add docs/grace-holy-bell.html docs/grace-phone-active.jpg \
        docs/grace-watch-active.jpg docs/grace-watch-log.jpg \
        docs/pray-sprite-strip.png
git commit -m "Add Grace's Holy Bell marketing landing page"
git push origin main
```

## Step 2 — mirror to production and push

```bash
cd ~/Developer
# clone if you don't already have it
git clone git@github.com:ebogin/Boginfactory-Landing-Page.git
cd Boginfactory-Landing-Page
cp ../graces-holy-bell/docs/grace-holy-bell.html .
cp ../graces-holy-bell/docs/grace-phone-active.jpg .
cp ../graces-holy-bell/docs/grace-watch-active.jpg .
cp ../graces-holy-bell/docs/grace-watch-log.jpg .
cp ../graces-holy-bell/docs/pray-sprite-strip.png .
git add grace-holy-bell.html grace-phone-active.jpg grace-watch-active.jpg \
        grace-watch-log.jpg pray-sprite-strip.png
git commit -m "Publish Grace's Holy Bell landing page"
git push origin main
```

## Step 3 — verify

- Open `https://boginfactory.com/grace-holy-bell.html`.
- Confirm: title, animated praying figure (should loop ~1.2s, one frame every 300ms),
  the iPhone + two Apple Watch Ultra device frames render the screenshots, feature cards,
  and the two Apple "Download on the App Store" badges.
- Footer links (Privacy Policy, Waitlist) resolve.

## Open TODO (must decide before real launch)

- **App Store badge links point to `#` (placeholder).** Both
  `<a class="app-store-badge" href="#">` in `grace-holy-bell.html` need the real App Store
  listing URL. Ask Eric for it, then set both `href`s (source `docs/` copy AND the prod
  copy) and re-push.
- The badge image loads from Apple's CDN
  (`developer.apple.com/assets/elements/badges/download-on-the-app-store.svg`). Optional:
  self-host the SVG in the repo for a fully self-contained page.

## Context / design notes

- Page mirrors the app's LCD-green "Game Boy" pixel theme (palette + Press Start 2P font),
  matching `docs/grace-waitlist.html` and `docs/graces-privacy-policy.html`.
- Palette source of truth: `Graces Holy Bell/Theme.swift`.
- Animated figure reproduces the app's `PrayingFigureView`: 4 frames
  (`pray_frame_1..4`), 300 ms/frame, 1.2 s loop, `image-rendering: pixelated`, with a
  `prefers-reduced-motion` fallback to a static frame.
- Device frames (iPhone + Apple Watch Ultra, incl. the Ultra's orange Action Button) are
  pure CSS — no external frame assets required.
- App Store copy this page is based on lives at
  `App Store Submission/App Store Metadata.md`.

## Suggested skills for the next session

- None required for the deploy itself (plain git).
- If editing the page copy/layout further, no special skill needed — it's a single
  self-contained HTML file.
- If asked to regenerate App Store text/screenshots, see `App Store Submission/`.
