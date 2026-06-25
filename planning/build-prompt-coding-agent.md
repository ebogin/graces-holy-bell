# Build Prompt — Coding Agent Chat (Component 1: Analytics)

> Paste the block below as the opening message of the **agent build chat**. Runs
> in parallel with the human-setup chat ([`build-prompt-human-setup.md`](build-prompt-human-setup.md)).

---

Act as a **senior iOS engineer**. We are implementing the **Analytics Plan
(Component 1)** for Grace's Holy Bell, an existing SwiftUI iPhone + Apple Watch
app. Work **strictly step-by-step and test-first (TDD)**.

**Read first, treat as source of truth:** `planning/project-handoff.md`,
`planning/analytics-plan.md`. Do not act on the viral-growth plan — it is a
separate, later effort.

**Working method — for every step:**
1. First propose the **modular file structure** and the **specific tests** we will
   write (TDD), plus any **product implications**.
2. **Stop and wait for my explicit approval** of the architecture before writing
   any implementation code.
3. Only then implement, make the tests pass, and verify (below).
Keep steps small and reviewable. Don't batch multiple phases.

**Scope & order:** Start at **Phase 1 (Foundation, no-op)**, then proceed one
phase at a time per the plan. Do **not** skip ahead.

**Hard constraints (non-negotiable invariants from the plan):**
- **Frozen core.** No behavior, logic, UI, or WatchConnectivity changes. You MAY
  add **additive, side-effect-free** analytics hook calls through the `Analytics`
  protocol — that is the instrumentation — but they must not alter control flow,
  ordering, or output. If a hook seems to need a logic change, **stop and ask**.
- **Thin abstraction.** All analytics go through one `Analytics` protocol in
  `Shared/`. View code never imports or touches the PostHog SDK directly.
- **Build against a mock/no-op transport.** Do NOT depend on real PostHog keys or
  accounts — those arrive from a separate human-setup chat. Build the entire
  abstraction + instrumentation + tests against an injectable mock so this chat is
  never blocked. Wiring the real PostHog SDK is a later handoff step.
- **Single anonymous identity.** One `install_id` (UserDefaults), generated on
  iPhone, synced to Watch; the **Watch never transmits before it holds the
  canonical id** (local pending queue + deterministic tie-break). No phantom users.
- **Watch proxies through the phone's SDK.** Preserve the **originating**
  `device_source` (never overwrite watch→phone) and each event's **true capture
  timestamp** via the SDK `timestamp` override (incl. the 12h synthesized
  `session_abandoned` at start+12h, and the no-double-close rule).
- **Anonymous-only, bucketed.** No PII, no prayer content, no raw second-level
  durations, country-geo only. Emit the on-device buckets defined in the plan.
- **Secrets.** Never hardcode or commit API keys. When real wiring comes, read keys
  from a gitignored xcconfig/secrets mechanism you propose; the PostHog **project**
  key may live in an (uncommitted) xcconfig; **personal** keys never enter the repo.

**Verification (every step):** use the **xcodebuild MCP** to build and run unit
tests on **both** the iPhone and the Apple Watch simulator schemes. Report real
results — if something fails or is skipped, say so with output. Do not claim done
without a green build + passing tests.

**Coordination with the human-setup chat:** you cannot create accounts, sign DPAs,
run the PostHog wizard, touch App Store Connect, or do TestFlight. When a step
needs a human-produced artifact (e.g. the PostHog project key, an installed MCP),
**emit a precise, copy-pasteable "ask"** for the human chat, then continue with
the mock so you're not blocked.

**Git:** small commit per approved step on a feature branch; conventional message
ending with the Co-Authored-By trailer. Do **not** push or open PRs unless I ask.

Before Phase 1, give me: (a) a one-paragraph restatement of the Phase-1 scope as
you understand it, (b) the proposed file structure, (c) the test list. Then wait.
