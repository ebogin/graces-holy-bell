import Foundation
import PostHog

/// Real PostHog transport behind the `Analytics` seam (iPhone only — the Watch
/// proxies through the phone under Option A).
///
/// IMPORTANT: `PostHogSDK.shared.setup(config)` unconditionally performs a
/// remote-config network fetch (`PostHogRemoteConfig.init` calls
/// `preloadRemoteConfig()` regardless of `preloadFeatureFlags`) — there is no
/// config flag that makes `setup` network-silent. That's why this type is
/// never constructed until consent is granted: `ConsentActivation` only calls
/// `PostHogTransport.make` the first time it sees `.granted`, and the
/// `SwappableAnalytics` seam swaps the resulting transport in in place of the
/// `NoOpAnalytics` the app starts with. It also never calls `identify` — the
/// install_id rides as `distinctId` on each `capture` — and capture itself is
/// gated upstream by `ConsentGatingAnalytics`, so nothing transmits until
/// consent is granted. The event's true `captureTimestamp` is passed through
/// (backdated events land at the right point on PostHog's timeline).
final class PostHogTransport: Analytics {

    private let installID: String

    /// Builds the transport when a real key is present; nil otherwise (-> no-op).
    /// Only call this after consent is granted — construction performs the
    /// remote-config network fetch described above.
    static func make(installID: String) -> PostHogTransport? {
        guard let secrets = SecretsStore.postHog() else { return nil }
        return PostHogTransport(secrets: secrets, installID: installID)
    }

    /// Opts the already-initialized SDK's own network traffic back in.
    /// Pass-through so callers outside this file never need to import PostHog.
    static func optIn() {
        PostHogSDK.shared.optIn()
    }

    /// Silences the already-initialized SDK's own network traffic. Used when
    /// consent is revoked after the real transport was activated — capture is
    /// already dropped upstream by `ConsentGatingAnalytics`, but this also
    /// stops the SDK's internal traffic (e.g. queued/retry flushes).
    /// Pass-through so callers outside this file never need to import PostHog.
    static func optOut() {
        PostHogSDK.shared.optOut()
    }

    private init(secrets: SecretsStore.PostHogSecrets, installID: String) {
        self.installID = installID

        let config = PostHogConfig(apiKey: secrets.apiKey, host: secrets.host)
        // We emit our own clean taxonomy — no autocapture noise (Phase 0 mandate).
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        // No feature flags in use. This does NOT prevent setup's network call
        // (see class doc) — it only skips the feature-flag payload itself.
        config.preloadFeatureFlags = false
        // We don't use any of these; keep the SDK's footprint to exactly the
        // events we emit ourselves.
        config.surveys = false
        config.sessionReplay = false
        config.captureElementInteractions = false

        PostHogSDK.shared.setup(config)
    }

    func capture(_ event: AnalyticsEvent) {
        PostHogSDK.shared.capture(
            event.name,
            distinctId: installID,
            properties: Self.mapProperties(event.properties),
            timestamp: event.captureTimestamp
        )
    }

    private static func mapProperties(_ props: [String: AnalyticsValue]) -> [String: Any] {
        props.mapValues { value -> Any in
            switch value {
            case let .string(s): return s
            case let .int(i): return i
            case let .double(d): return d
            case let .bool(b): return b
            }
        }
    }
}
