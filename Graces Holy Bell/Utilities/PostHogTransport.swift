import Foundation
import PostHog

/// Real PostHog transport behind the `Analytics` seam (iPhone only — the Watch
/// proxies through the phone under Option A).
///
/// Consent-safe by construction: it never calls `identify` and disables feature-
/// flag preloading, so `setup` performs no network call. The install_id rides as
/// `distinctId` on each `capture`, and capture itself is gated upstream by
/// `ConsentGatingAnalytics`, so nothing transmits until consent is granted.
/// The event's true `captureTimestamp` is passed through (backdated events land
/// at the right point on PostHog's timeline).
final class PostHogTransport: Analytics {

    private let installID: String

    /// Builds the transport when a real key is present; nil otherwise (-> no-op).
    static func make(installID: String) -> PostHogTransport? {
        guard let secrets = SecretsStore.postHog() else { return nil }
        return PostHogTransport(secrets: secrets, installID: installID)
    }

    private init(secrets: SecretsStore.PostHogSecrets, installID: String) {
        self.installID = installID

        let config = PostHogConfig(apiKey: secrets.apiKey, host: secrets.host)
        // We emit our own clean taxonomy — no autocapture noise (Phase 0 mandate).
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        // No feature flags in use; disabling avoids any network call on setup
        // (important so nothing hits PostHog before consent is granted).
        config.preloadFeatureFlags = false

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
