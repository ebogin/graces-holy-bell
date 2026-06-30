import Foundation

/// The single seam between app code and any analytics backend.
///
/// View and view-model code depend only on this protocol — never on the PostHog
/// SDK directly. The shipping default is ``NoOpAnalytics``; tests inject a
/// recording spy; the real PostHog transport is swapped in behind this same
/// protocol at the Phase 0→2 handoff, with no changes to call sites.
protocol Analytics {
    /// Records an anonymous event. Implementations must be side-effect-free with
    /// respect to app behavior (analytics never alters control flow or output).
    func capture(_ event: AnalyticsEvent)
}
