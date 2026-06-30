import Foundation

/// `Analytics` decorator that enforces consent at the transmission boundary.
///
/// Forwards to the wrapped transport only when consent is granted; otherwise the
/// event is dropped. Pre-consent events are never buffered or retroactively sent.
/// Wraps the no-op transport today and the real PostHog transport at the 0→2
/// handoff — so transmission is consent-gated regardless of the backend.
final class ConsentGatingAnalytics: Analytics {

    private let wrapped: Analytics
    private let isGranted: () -> Bool

    init(wrapping wrapped: Analytics, isGranted: @escaping () -> Bool) {
        self.wrapped = wrapped
        self.isGranted = isGranted
    }

    func capture(_ event: AnalyticsEvent) {
        guard isGranted() else { return }
        wrapped.capture(event)
    }
}
