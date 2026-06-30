import Foundation

/// Shipping default transport: does nothing.
///
/// Lets the entire analytics abstraction — and, in Phase 2, the instrumentation
/// hooks — build, run, and ship with no PostHog keys or account. The real
/// transport replaces this at the Phase 0→2 handoff.
struct NoOpAnalytics: Analytics {
    init() {}
    func capture(_ event: AnalyticsEvent) {}
}
