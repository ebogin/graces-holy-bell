import Foundation

/// Local, compile-time feature flags for gating in-progress features.
///
/// These are plain constants — flip a value and rebuild. Unlike the PostHog
/// remote flags (analytics/experiments), these exist to hide UI that isn't
/// ready to ship without deleting the code behind it.
///
/// Lives in `Shared/` so the same constant governs BOTH the iPhone and Watch
/// targets — a single flip hides a feature everywhere. (Flags that only the
/// phone references, like `prayerHistoryEnabled`/`welcomeMessageEnabled`, are
/// simply unused on the Watch — harmless.)
enum FeatureFlags {

    /// In-app Prayer History (Settings → PRAYER LOG → History) and its calendar
    /// browser. Off: the settings row is hidden. Session archiving still runs in
    /// the background, so no history is lost while this is disabled — turning it
    /// back on surfaces everything recorded in the meantime.
    ///
    /// Disabled 2026-07-06: history view has known display bugs; deferred.
    static let prayerHistoryEnabled = false

    /// Remote-configurable idle-screen welcome message (RemoteConfig.swift /
    /// WelcomeMessageView.swift), fetched from the grace-waitlist Worker. Off:
    /// no config fetch runs and the idle screen shows the bundled default
    /// message, unchanged from before this feature existed. RemoteConfig,
    /// WelcomeMessageView, the Worker endpoint, and their tests are untouched
    /// and ready to flip back on.
    ///
    /// Left out of the 1.5x release 2026-07-13: kept off the critical path
    /// while it settles.
    static let welcomeMessageEnabled = false

    /// Per-prayer figure actions — the "prayer swipe narrative": after each
    /// PRAY swipe the figure performs a remotely-configured action (placeholder
    /// scaffolding today — see ANIMATIONS.md / HANDOFF-prayer-animations.md)
    /// before returning to praying. Off: the figure just keeps praying (prior
    /// behavior), and no animations config is fetched on either platform.
    ///
    /// Gated on BOTH iPhone and Watch (this file is Shared). Kept **off** on
    /// main — the feature is still in development (real artwork, change
    /// pipeline, and an admin UI are pending). Flip to `true` to work on it or
    /// once it's ready to ship.
    static let prayerActionsEnabled = false

    /// The full-screen AMEN takeover era of the Amen Alarm — everything added
    /// in `e01c4da` and after: the ringing bell-tower takeover (phone + Watch),
    /// the `bell_alarm.caf` Loud Bell option, the 30-second haptic patterns,
    /// the follow-up `.repeatN` notification burst, and the notification-tap
    /// re-anchoring.
    ///
    /// Off: the alarm reverts to its pre-takeover behavior — the PRAY slider
    /// doubles as a progress bar and blinks "AMEN!" for 5 seconds at the
    /// interval, backed by exactly ONE silent local notification. That blink
    /// layer was never removed, so nothing needs restoring; the takeover was
    /// only ever drawn on top of it.
    ///
    /// Gated on BOTH iPhone and Watch (this file is Shared). Turned off
    /// 2026-07-22 to ship: the takeover era carries five open bugs — a burst of
    /// four notifications mirroring to the wrist, over-frequent Watch haptics,
    /// the takeover re-presenting itself after a notification tap, wrong
    /// notification copy, and an already-elapsed alarm re-firing when the Phone
    /// toggle is switched on. None of the code is deleted; flip to `true` to
    /// pick the work back up.
    static let amenTakeoverEnabled = false
}
