#!/usr/bin/env bash
#
# grace-welcome.sh — publish / verify / roll back the app's remote welcome message.
#
# The idle-screen welcome text (and optional image / detail sheet) is served by the
# grace-waitlist Cloudflare Worker, not baked into the app. Changing it needs no build
# and no App Store review — just a token-protected POST. This script does the mechanical
# part safely: resolves the ADMIN_TOKEN, validates the payload against the app's tolerant
# schema, publishes, and echoes back what actually got stored.
#
# See ../../../WELCOME_MESSAGE.md (repo root) for the full protocol and schema.
#
# Usage:
#   grace-welcome.sh verify                 # print what's currently live (public endpoint)
#   grace-welcome.sh validate <file.json>   # schema-check a payload, no network
#   grace-welcome.sh post <file.json> --yes # publish a payload (requires --yes or a TTY)
#   grace-welcome.sh rollback --yes         # publish the single default catch-all message
#
# Options:
#   --yes            Skip the interactive confirm (publishing is outward-facing — only pass
#                    this after the user has explicitly approved the change in chat).
#   --host HOST      Override the admin host (default: the workers.dev hostname below).
#   --public URL     Override the public GET endpoint used by `verify`.
#
set -euo pipefail

ADMIN_HOST="grace-waitlist.grace-waitlist.workers.dev"
PUBLIC_URL="https://boginfactory.com/app-config"
MAX_VALUE_BYTES=$((32 * 1024))   # Worker's per-key limit (postAppConfig in waitlist/src/index.js)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repo root is three levels up from .claude/skills/grace-welcome/ (works from a worktree too).
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

c_red=$'\033[31m'; c_yellow=$'\033[33m'; c_green=$'\033[32m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
err()  { printf '%sERROR%s %s\n' "$c_red" "$c_off" "$*" >&2; }
warn() { printf '%swarn%s  %s\n' "$c_yellow" "$c_off" "$*" >&2; }
ok()   { printf '%s✓%s %s\n' "$c_green" "$c_off" "$*" >&2; }
die()  { err "$*"; exit 1; }

command -v jq   >/dev/null 2>&1 || die "jq is required but not found on PATH."
command -v curl >/dev/null 2>&1 || die "curl is required but not found on PATH."

# ── ADMIN_TOKEN resolution ───────────────────────────────────────────────────
# Priority: existing env var → waitlist/.dev.vars (gitignored) → repo .env (gitignored).
# Cloudflare never lets you read a secret back out, so the token has to live locally.
resolve_token() {
  if [[ -n "${ADMIN_TOKEN:-}" ]]; then return 0; fi
  local f
  for f in "$REPO_ROOT/waitlist/.dev.vars" "$REPO_ROOT/.env" "$REPO_ROOT/waitlist/.env"; do
    [[ -f "$f" ]] || continue
    # Pull the ADMIN_TOKEN=… line only; tolerate optional quotes/export prefix.
    local line
    line="$(grep -E '^[[:space:]]*(export[[:space:]]+)?ADMIN_TOKEN=' "$f" | tail -n1 || true)"
    [[ -n "$line" ]] || continue
    ADMIN_TOKEN="${line#*=}"
    ADMIN_TOKEN="${ADMIN_TOKEN%\"}"; ADMIN_TOKEN="${ADMIN_TOKEN#\"}"
    ADMIN_TOKEN="${ADMIN_TOKEN%\'}"; ADMIN_TOKEN="${ADMIN_TOKEN#\'}"
    if [[ -n "$ADMIN_TOKEN" ]]; then
      printf '%susing ADMIN_TOKEN from %s%s\n' "$c_dim" "$f" "$c_off" >&2
      return 0
    fi
  done
  cat >&2 <<EOF
${c_red}ERROR${c_off} ADMIN_TOKEN not found.

  It is the same Worker secret used for the waitlist CSV exports. Cloudflare does
  not let you read a secret's value back, so keep a local copy. Provide it one of:

    • export ADMIN_TOKEN=…            (this shell)
    • waitlist/.dev.vars              → line:  ADMIN_TOKEN=…   (already gitignored)

  If it was never set, set it once from waitlist/:  npx wrangler secret put ADMIN_TOKEN
EOF
  exit 1
}

# ── Payload validation (against the app's tolerant schema) ───────────────────
# Errors block publishing; warnings are surfaced but allowed (the app ignores unknown
# fields/types by design, so a warning is a heads-up, not a hard stop).
validate_payload() {
  local file="$1"
  [[ -f "$file" ]] || die "No such file: $file"
  jq empty "$file" 2>/dev/null || die "Not valid JSON: $file"

  local problems=0

  jq -e 'has("welcome")' "$file" >/dev/null 2>&1 \
    || { err "Top-level object must have a \"welcome\" key (POST body is {\"welcome\": {…}})."; problems=$((problems+1)); }
  jq -e '.welcome.messages | type == "array" and length >= 1' "$file" >/dev/null 2>&1 \
    || { err "welcome.messages must be a non-empty array."; problems=$((problems+1)); }

  # Size: the Worker rejects any single key's serialized value over 32 KiB.
  local bytes
  bytes="$(jq -c '.welcome' "$file" | wc -c | tr -d ' ')"
  if [[ "$bytes" -gt "$MAX_VALUE_BYTES" ]]; then
    err "welcome value is ${bytes} bytes, over the Worker's ${MAX_VALUE_BYTES}-byte limit."
    problems=$((problems+1))
  fi

  [[ "$problems" -eq 0 ]] || die "$problems blocking problem(s) — not publishing. Fix and re-run."

  # ── Warnings (non-blocking) ──
  # Trailing catch-all: without an audience:"all" last message, unmatched users fall back
  # to the app's bundled default line.
  if [[ "$(jq -r '.welcome.messages[-1].audience // "all"' "$file")" != "all" ]]; then
    warn "Last message's audience is not \"all\". Users matching nothing will see the app's"
    warn "bundled default instead. End the list with an audience:\"all\" catch-all."
  fi

  # Unknown audiences match nothing (by design — safe for forward-compat, but easy to typo).
  # `|| true` keeps a no-match grep (exit 1) from tripping `set -o pipefail`.
  local bad_aud
  bad_aud="$(jq -r '.welcome.messages[].audience // "all"' "$file" \
    | grep -Ev '^(all|watch_installed|watch_not_installed)$' | sort -u || true)"
  if [[ -n "$bad_aud" ]]; then
    while read -r a; do
      [[ -n "$a" ]] && warn "Unrecognized audience \"$a\" — this message will match NO users (typo?)."
    done <<<"$bad_aud"
  fi

  # Non-https images are silently dropped by the app.
  local bad_img
  bad_img="$(jq -r '[.. | objects | select(.type=="image") | .url // empty] | .[]' "$file" \
    | grep -v '^https://' || true)"
  if [[ -n "$bad_img" ]]; then
    while read -r u; do
      [[ -n "$u" ]] && warn "Image url is not https:// — the app drops this block: $u"
    done <<<"$bad_img"
  fi

  # Idle-screen text is a small fixed area; long copy belongs in a detail sheet.
  local idle_chars
  idle_chars="$(jq -r '[.welcome.messages[].blocks[]? | select(.type=="text") | .value] | add // "" | length' "$file")"
  if [[ "${idle_chars:-0}" -gt 200 ]]; then
    warn "≈${idle_chars} chars of idle-screen text across messages — it renders in a small pixel"
    warn "font above \"SLIDE TO BEGIN\". Keep each screen under ~120 chars; move long copy to detail."
  fi

  ok "Payload valid (${bytes} bytes)."
}

pretty() { jq . 2>/dev/null || cat; }

confirm_or_die() {
  local prompt="$1"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then return 0; fi
  if [[ ! -t 0 ]]; then
    die "This publishes to what every app user sees. Re-run with --yes after confirming with the user."
  fi
  printf '%s [y/N] ' "$prompt" >&2
  local reply; read -r reply </dev/tty || true
  [[ "$reply" =~ ^[Yy]$ ]] || die "Aborted."
}

do_post() {
  local body="$1"   # a JSON string
  resolve_token
  local resp http
  resp="$(curl -sS --connect-timeout 15 --max-time 60 -w $'\n%{http_code}' -X POST "https://$ADMIN_HOST/admin/app-config" \
            -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            --data-binary "$body")"
  http="${resp##*$'\n'}"
  body="${resp%$'\n'*}"
  if [[ "$http" != "200" ]]; then
    err "Publish failed (HTTP $http):"
    printf '%s\n' "$body" | pretty >&2
    [[ "$http" == "401" ]] && err "401 = ADMIN_TOKEN is wrong or unset in the Worker."
    exit 1
  fi
  ok "Published. The Worker echoed back the stored config (authoritative, uncached):"
  printf '%s\n' "$body" | pretty
  printf '\n' >&2
  warn "Public $PUBLIC_URL is edge-cached up to 5 min; the app also self-throttles refetch to"
  warn "once / 15 min / device. New copy shows on the next launch/foreground after both elapse."
}

cmd="${1:-}"; shift || true

# Parse shared flags out of the remaining args.
ASSUME_YES=0
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)     ASSUME_YES=1; shift ;;
    --host)    ADMIN_HOST="$2"; shift 2 ;;
    --public)  PUBLIC_URL="$2"; shift 2 ;;
    -h|--help) cmd="help"; shift ;;
    *)         POSITIONAL+=("$1"); shift ;;
  esac
done

case "$cmd" in
  verify)
    curl -fsS --connect-timeout 15 --max-time 60 "$PUBLIC_URL" | pretty
    printf '%s(public endpoint — edge-cached up to 5 min, may lag a just-published change)%s\n' \
      "$c_dim" "$c_off" >&2
    ;;

  validate)
    [[ "${#POSITIONAL[@]}" -ge 1 ]] || die "Usage: grace-welcome.sh validate <file.json>"
    validate_payload "${POSITIONAL[0]}"
    ;;

  post|publish)
    [[ "${#POSITIONAL[@]}" -ge 1 ]] || die "Usage: grace-welcome.sh post <file.json> [--yes]"
    file="${POSITIONAL[0]}"
    validate_payload "$file"
    printf '\n%s── payload to publish ──%s\n' "$c_dim" "$c_off" >&2
    jq . "$file" >&2
    printf '\n' >&2
    confirm_or_die "Publish this to every app user's idle screen?"
    do_post "$(cat "$file")"
    ;;

  rollback)
    body='{"welcome":{"version":1,"messages":[{"id":"default","audience":"all","blocks":[{"type":"text","value":"Welcome to your favorite app to time prayer duration."}]}]}}'
    printf '%sRollback payload (the original seed / default line):%s\n' "$c_dim" "$c_off" >&2
    printf '%s\n' "$body" | pretty >&2
    printf '\n' >&2
    confirm_or_die "Roll back to the single default catch-all message?"
    do_post "$body"
    ;;

  help|"")
    # Print the leading comment block (from line 3 to the first non-comment line), de-hashed.
    awk 'NR>=3 && /^#/ {sub(/^# ?/,""); print; next} NR>=3 {exit}' "${BASH_SOURCE[0]}"
    ;;

  *)
    die "Unknown command: $cmd  (try: verify | validate | post | rollback | help)"
    ;;
esac
