import Foundation
import Observation
import os

/// Watch-side fetch of the remotely-configurable prayer action manifest (the
/// "animations" key of GET /app-config — see ANIMATIONS.md). The iPhone reads
/// the same endpoint via RemoteConfig; the Watch fetches its own copy so the
/// figure's per-prayer actions stay updatable without an app build even when
/// the iPhone isn't reachable.
///
/// Fail-silent, never blocks: `currentPrayerActions` always returns something
/// (cached → bundled default), and a failed/throttled/malformed fetch leaves
/// the current state untouched. Deliberately mirrors the phone's RemoteConfig,
/// trimmed to just the animations key. Decodes into the SHARED
/// `PrayerActionsConfig`, so both platforms interpret the manifest identically.
///
/// (An alternative delivery path — piping the phone's already-fetched manifest
/// down over WatchConnectivity — is noted in HANDOFF-prayer-animations.md; a
/// direct fetch is used here to keep the scaffolding self-contained and off the
/// sync/SyncedState surface.)
@MainActor
@Observable
final class WatchAnimationConfigStore {

    static let configURL = URL(string: "https://boginfactory.com/app-config")!

    /// Fetched/cached manifest, or nil until one lands. Callers use
    /// `currentPrayerActions`, which falls back to the bundled default.
    private(set) var animations: PrayerActionsConfig?

    /// Never nil, so the active screen always has a sequence to play.
    var currentPrayerActions: PrayerActionsConfig {
        animations ?? .bundledDefault
    }

    private static let throttleInterval: TimeInterval = 15 * 60

    private let defaults: UserDefaults
    private let fetchData: (URLRequest) async throws -> (Data, URLResponse)
    private let logger = Logger(subsystem: "Boginfactory.Graces-Holy-Bell.watchkitapp", category: "animationConfig")

    private enum Keys {
        static let raw = "watchAnimationConfig.raw"
        static let lastFetchAt = "watchAnimationConfig.lastFetchAt"
    }

    /// `fetchData` is injectable so tests can stub responses without a real
    /// URLSession round-trip — mirrors the phone's RemoteConfig.
    init(
        defaults: UserDefaults = .standard,
        fetchData: @escaping (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.defaults = defaults
        self.fetchData = fetchData
        if let cached = defaults.data(forKey: Keys.raw) {
            self.animations = try? JSONDecoder().decode(PrayerActionsConfig.self, from: cached)
        }
    }

    /// Fetches the latest manifest in the background. Throttled to once per 15
    /// minutes from the last *successful* fetch. Any failure — network, non-200,
    /// missing "animations" key, malformed JSON — leaves `animations` untouched.
    func refresh() async {
        if let last = defaults.object(forKey: Keys.lastFetchAt) as? Date,
           Date().timeIntervalSince(last) < Self.throttleInterval {
            return
        }
        do {
            var request = URLRequest(url: Self.configURL)
            request.timeoutInterval = 10
            let (data, response) = try await fetchData(request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                logger.debug("app-config fetch: unexpected response")
                return
            }
            guard
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let animationsObject = root["animations"]
            else {
                return
            }
            let animationsData = try JSONSerialization.data(withJSONObject: animationsObject)
            let decoded = try JSONDecoder().decode(PrayerActionsConfig.self, from: animationsData)

            defaults.set(animationsData, forKey: Keys.raw)
            defaults.set(Date(), forKey: Keys.lastFetchAt)
            animations = decoded
        } catch {
            logger.debug("app-config fetch failed: \(String(describing: error), privacy: .public)")
        }
    }
}
