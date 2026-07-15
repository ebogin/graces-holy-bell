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
}
