# Grace's Holy Bell — Product Specification
**Version 1.0 | For use with Claude Code**

---

## Purpose of This Document

Paste this document at the start of every Claude Code session to provide full project context. It is the authoritative reference for all product decisions.

---

## App Overview

**Name:** Grace's Holy Bell  
**Platforms:** iOS (iPhone) + watchOS (Apple Watch)  
**Frameworks:** SwiftUI, SwiftData, WatchConnectivity  
**Personal use initially; App Store submission planned for future**

Grace's Holy Bell is a prayer interval tracker for religious practitioners who pray at self-determined intervals throughout the day. It tracks the time between prayers, logs the history of each prayer session, and provides intentional, slider-based controls to prevent accidental interactions. Integrity of timekeeping is the app's highest priority.

---

## Architecture

### Source of Truth: iPhone
- The iPhone app owns all data and all timing logic
- The Watch app is a full-featured remote interface into that data
- This ensures reliable background timekeeping — the iPhone maintains the clock even when the Watch screen is off or the Watch app is closed

### Storage: SwiftData (on iPhone)
- All prayer sessions and log entries are persisted on iPhone
- WatchConnectivity syncs state to/from the Watch in real time

### Timer Logic: Timestamp-Based (Never Counter-Based)
- When a prayer is logged, store the exact timestamp (`Date()`)
- Calculate elapsed time as `Date.now - storedTimestamp`
- This means the timer is always accurate regardless of app state, screen sleep, or backgrounding
- Never use a running counter or timer that increments — these are fragile and can drift or reset

### Sync: WatchConnectivity
- Two-way sync between iPhone and Watch
- Watch sends user actions (PRAY, STOP) to iPhone for processing
- iPhone sends updated state (current session, full log) back to Watch for display
- If Watch and iPhone are temporarily out of range, actions queue and sync on reconnect

---

## App States

The app has two states:

### IDLE
- No active prayer session
- Clock is stopped
- Log from the most recent completed session is visible (read-only)
- PRAY slider is available to start a new session
- Starting a new session from IDLE **implicitly clears the previous session's log** (with confirmation — see below)

### ACTIVE SESSION
- A prayer session is in progress
- Clock is running, showing elapsed time since most recent prayer
- Log is growing as prayers are recorded
- PRAY slider logs the current prayer and immediately starts the next interval
- STOP option available (with confirmation) to end the session

---

## Core Interactions

### The PRAY Slider
- A single, unified slider control used for all prayer-logging actions
- Appears identically in both contexts:
  - **From IDLE:** Starts a new prayer session (clears old log — see confirmation below)
  - **During ACTIVE SESSION:** Logs current prayer + immediately starts the next interval timer
- Slider must be dragged deliberately to trigger — prevents accidental activation
- Same slider is used on both iPhone and Apple Watch

### The STOP Button
- Ends the current ACTIVE SESSION
- Clock stops; no final prayer entry is recorded
- Log is preserved and remains viewable in IDLE state
- **Requires confirmation dialog before executing** (e.g., "End prayer session? The clock will stop and no final prayer will be recorded.")
- After confirmation, app transitions to IDLE state

### New Session Confirmation
- When user slides PRAY from IDLE state (starting a new session)
- App detects that a previous session log exists
- **Requires confirmation dialog** (e.g., "Start new session? Your previous prayer log will be cleared.")
- On confirm: log is wiped, new session begins, first prayer timestamp recorded
- On cancel: nothing happens, app remains in IDLE

### Reset (No Separate Reset Function)
- There is no standalone "Reset" button
- The act of starting a new session IS the reset
- This is intentional — one fewer destructive action to protect against

---

## Prayer Log Format

The log shows a chronological record of the current (or most recent) session.

```
Prayer #1    5:00 AM
Duration #1  2h 14m 32s

Prayer #2    7:14 AM
Duration #2  14m 00s

Prayer #3    7:28 AM
Duration #3  <live running timer — updates every second>
```

**Rules:**
- Prayer time = wall clock time when PRAY was slid (formatted as h:mm AM/PM)
- Duration = elapsed time between that prayer and the next (or ongoing elapsed time for the most recent entry)
- The final duration row always shows the live running timer during ACTIVE SESSION
- In IDLE state, the final duration row shows the stopped time (frozen at when STOP was pressed)
- Log is flat and chronological — no grouping by date
- Log can grow as long as needed; no maximum entry limit
- Scroll to view full log on both iPhone and Watch

---

## Screen Layouts

### iPhone — IDLE State
- App name / header
- "No active session" indicator (or last session end time)
- Previous session log (scrollable, read-only)
- PRAY slider at bottom (prominent)

### iPhone — ACTIVE SESSION State
- Large live elapsed timer (HH:MM:SS) — time since last prayer
- Prayer log (scrollable) — grows with each prayer
- PRAY slider (logs prayer + restarts timer)
- STOP button (with confirmation)

### Apple Watch — IDLE State
- Compact "No active session" message
- Previous log (scrollable via Digital Crown)
- PRAY slider

### Apple Watch — ACTIVE SESSION State
- Large live elapsed timer (HH:MM:SS)
- Recent log entries (scrollable via Digital Crown)
- PRAY slider
- STOP button

---

## UI Phases

### Phase 1 (Build First): Functional Prototype
- Clean, minimal SwiftUI
- Standard system fonts, colors, and components
- Focus entirely on correct behavior and data integrity
- No custom graphics or theming

### Phase 2 (Later): Pixel-Art / Retro Theme
- Visual reskin with pixel/8-bit game aesthetic
- Custom fonts, sprites, animations
- **The logic layer must remain completely separate from the UI layer throughout Phase 1 so Phase 2 can be applied as a skin without rebuilding functionality**
- Think: old church bell tower game graphics

---

## What This App Does NOT Do
- No push notifications or reminders
- No watch face complications
- No fixed/scheduled prayer times (fully interval-based, user-initiated)
- No grouping or filtering of log by date
- No export or sharing of log data (v1)
- No audio (v1)
- No health/HealthKit integration

---

## Technical Notes for Claude Code

- Use **SwiftUI** throughout — no UIKit or AppKit
- Use **SwiftData** for persistence (not CoreData, not UserDefaults for session data)
- Use **WatchConnectivity** for Watch ↔ iPhone sync
- Timer display should update every second using a `TimelineView` or `Timer.publish` — but the *source of truth* is always the stored `Date` timestamp, not an incrementing counter
- Slider component: use SwiftUI's built-in `Slider` or a custom drag gesture — must require intentional full-swipe to trigger, not a tap
- Keep business logic in ViewModels / a shared data layer — keep Views as thin as possible (required for Phase 2 reskin)
- Target: iOS 17+ and watchOS 10+ (enables SwiftData and latest SwiftUI features)

---

## Open Questions / Future Decisions
- App icon and name treatment (Phase 2)
- Whether to support iPad (not required for v1)
- App Store category (Health & Fitness? Lifestyle? Utilities?)
- Whether to add iCloud sync across devices in a future version
