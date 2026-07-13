import Foundation

/// Activates the real analytics transport the first time consent is granted.
///
/// SDK-free by design (no PostHog import — testable without the SDK). Owns a
/// one-shot latch: `activateIfGranted` only ever builds and swaps in the real
/// transport once, no matter how many times it's called with `.granted` (e.g.
/// once synchronously at launch for already-granted users, and again from
/// `.onChange(of: consent.state)` for users who grant later). `.pending` and
/// `.denied` never trigger construction, so nothing that touches the network
/// is built before consent exists.
final class ConsentActivation {

    private var activated = false

    /// Builds and swaps in the real transport on the first `.granted` state
    /// seen. `makeTransport` is only invoked once, and only when granted; a
    /// `nil` result (e.g. no PostHog key present) still counts as activation
    /// attempted, so we don't keep retrying against a missing key.
    func activateIfGranted(
        _ state: ConsentState,
        swappable: SwappableAnalytics,
        makeTransport: () -> Analytics?
    ) {
        guard state == .granted, !activated else { return }
        activated = true
        guard let transport = makeTransport() else { return }
        swappable.swap(to: transport)
    }
}
