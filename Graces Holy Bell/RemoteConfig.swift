import SwiftUI
import Observation
import os

// MARK: - Welcome message models
//
// Decoded from the "welcome" key of GET /app-config (grace-waitlist Worker).
// See WELCOME_MESSAGE.md at the repo root for the schema and how to update
// the live content. Decoding is deliberately tolerant everywhere: unknown
// block types, unknown audience values, and unknown enum-ish strings never
// fail the whole config — they degrade to `.unknown` / a default, so old app
// versions keep working against content authored for newer ones.

struct WelcomeConfig: Decodable {
    var version: Int?
    var messages: [WelcomeMessage]
}

struct WelcomeMessage: Decodable {
    var id: String?
    /// Raw audience string, matched by `RemoteConfig.currentMessage` against
    /// known cases. An unrecognized value matches nothing (message skipped),
    /// which is what keeps future audience types backward-compatible.
    var audience: String?
    var blocks: [WelcomeBlock]
    var detail: WelcomeDetail?
}

struct WelcomeDetail: Decodable {
    var title: String?
    var blocks: [WelcomeBlock]
}

enum WelcomeTextAlign: String, Decodable {
    case leading, center, trailing
}

enum WelcomeTextSize: String, Decodable {
    case small, body, large

    var points: CGFloat {
        switch self {
        case .small: return 10
        case .body: return 12
        case .large: return 16
        }
    }
}

enum WelcomePaletteColor: String, Decodable {
    case dark, mid

    var color: Color {
        switch self {
        case .dark: return .lcdDark
        case .mid: return .lcdMid
        }
    }
}

enum WelcomeLinkDestination {
    case detail
    case url(URL)
}

enum WelcomeBlock: Decodable {
    case text(value: String, align: WelcomeTextAlign, size: WelcomeTextSize, color: WelcomePaletteColor)
    case image(url: URL, caption: String?)
    case link(label: String, destination: WelcomeLinkDestination)
    /// Any unrecognized block type, or a known type missing its required
    /// field(s) — rendered as nothing, never a decode failure.
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type, value, align, size, color, url, caption, label, destination
    }

    private static let maxTextLength = 1000

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? container.decode(String.self, forKey: .type)) ?? ""

        switch type {
        case "text":
            guard let raw = try? container.decode(String.self, forKey: .value) else {
                self = .unknown
                return
            }
            let value = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxTextLength))
            guard !value.isEmpty else {
                self = .unknown
                return
            }
            let align = (try? container.decode(WelcomeTextAlign.self, forKey: .align)) ?? .leading
            let size = (try? container.decode(WelcomeTextSize.self, forKey: .size)) ?? .body
            let color = (try? container.decode(WelcomePaletteColor.self, forKey: .color)) ?? .dark
            self = .text(value: value, align: align, size: size, color: color)

        case "image":
            guard
                let urlString = try? container.decode(String.self, forKey: .url),
                let url = URL(string: urlString),
                url.scheme == "https"
            else {
                self = .unknown
                return
            }
            let caption = (try? container.decode(String.self, forKey: .caption))
                .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxTextLength)) }
            self = .image(url: url, caption: (caption?.isEmpty ?? true) ? nil : caption)

        case "link":
            guard
                let rawLabel = try? container.decode(String.self, forKey: .label),
                let destinationString = try? container.decode(String.self, forKey: .destination)
            else {
                self = .unknown
                return
            }
            let label = String(rawLabel.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxTextLength))
            guard !label.isEmpty else {
                self = .unknown
                return
            }
            if destinationString == "detail" {
                self = .link(label: label, destination: .detail)
            } else if let url = URL(string: destinationString), url.scheme == "https" {
                self = .link(label: label, destination: .url(url))
            } else {
                self = .unknown
            }

        default:
            self = .unknown
        }
    }
}

// MARK: - RemoteConfig

/// Fetches and caches the remotely-configurable app content (currently just
/// the idle-screen welcome message) from the `grace-waitlist` Worker.
///
/// Fail silent, never block: the idle screen always has something to render
/// from `welcome` (cache) or `Self.defaultWelcome` (bundled fallback) before
/// `refresh()` is ever called, and a failed/throttled/malformed fetch simply
/// leaves the current state untouched.
@MainActor
@Observable
final class RemoteConfig {

    static let configURL = URL(string: "https://boginfactory.com/app-config")!

    /// Decoded from the raw cached bytes (or the last successful fetch).
    private(set) var welcome: WelcomeConfig?

    /// Bundled fallback — used when there's no cache yet and when no
    /// message's audience matches the caller's local state.
    static let defaultWelcome = WelcomeConfig(
        version: 1,
        messages: [
            WelcomeMessage(
                id: "bundled-default",
                audience: "all",
                blocks: [
                    .text(
                        value: "Welcome to your favorite app to time prayer duration.",
                        align: .leading,
                        size: .body,
                        color: .dark
                    )
                ],
                detail: nil
            )
        ]
    )

    private static let throttleInterval: TimeInterval = 15 * 60

    private let defaults: UserDefaults
    private let fetchData: (URLRequest) async throws -> (Data, URLResponse)
    private let logger = Logger(subsystem: "Boginfactory.Graces-Holy-Bell", category: "remoteConfig")

    private enum Keys {
        static let raw = "remoteConfig.welcome.raw"
        static let lastFetchAt = "remoteConfig.welcome.lastFetchAt"
    }

    /// `fetchData` is injectable so tests can stub network responses without
    /// a real URLSession round-trip — mirrors the store-protocol fakes used
    /// elsewhere in this codebase (e.g. `InstallIDStore`).
    init(
        defaults: UserDefaults = .standard,
        fetchData: @escaping (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.defaults = defaults
        self.fetchData = fetchData
        if let cached = defaults.data(forKey: Keys.raw) {
            self.welcome = try? JSONDecoder().decode(WelcomeConfig.self, from: cached)
        }
    }

    /// Fetches the latest config in the background. Throttled to once per
    /// 15 minutes (measured from the last *successful* fetch) so app
    /// foregrounding can't hammer the Worker. Any failure — network,
    /// non-200, missing "welcome" key, malformed JSON — leaves `welcome`
    /// exactly as it was.
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
                let welcomeObject = root["welcome"]
            else {
                return
            }
            let welcomeData = try JSONSerialization.data(withJSONObject: welcomeObject)
            let decoded = try JSONDecoder().decode(WelcomeConfig.self, from: welcomeData)

            defaults.set(welcomeData, forKey: Keys.raw)
            defaults.set(Date(), forKey: Keys.lastFetchAt)
            welcome = decoded
        } catch {
            logger.debug("app-config fetch failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// First message whose audience matches, falling back to the bundled
    /// default if nothing does (including when no config has loaded yet).
    func currentMessage(isWatchAvailable: Bool) -> WelcomeMessage {
        let config = welcome ?? Self.defaultWelcome
        for message in config.messages where matches(message.audience, isWatchAvailable: isWatchAvailable) {
            return message
        }
        return Self.defaultWelcome.messages[0]
    }

    private func matches(_ audience: String?, isWatchAvailable: Bool) -> Bool {
        switch audience {
        case "all": return true
        case "watch_not_installed": return !isWatchAvailable
        case "watch_installed": return isWatchAvailable
        default: return false
        }
    }
}
