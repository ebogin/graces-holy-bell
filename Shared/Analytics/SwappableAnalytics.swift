import Foundation

/// `Analytics` decorator that lets the underlying transport be replaced after
/// construction.
///
/// `AnalyticsService` holds its transport as an immutable `let`, but the real
/// PostHog transport must not be constructed until consent is granted (its
/// `setup()` call fires a network request — see `PostHogTransport`). This class
/// is the fixed transport `AnalyticsService` is built with up front (wrapping
/// `NoOpAnalytics`); `ConsentActivation` swaps in the real transport in place,
/// once, the moment consent is granted. All call sites keep capturing through
/// the same seam throughout — nothing needs to be rebuilt.
final class SwappableAnalytics: Analytics {

    private let lock = NSLock()
    private var wrapped: Analytics

    init(initial: Analytics) {
        self.wrapped = initial
    }

    /// Replaces the underlying transport. Safe to call from any thread.
    func swap(to transport: Analytics) {
        lock.lock()
        wrapped = transport
        lock.unlock()
    }

    func capture(_ event: AnalyticsEvent) {
        lock.lock()
        let current = wrapped
        lock.unlock()
        current.capture(event)
    }
}
