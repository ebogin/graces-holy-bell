import Foundation

/// Reads PostHog secrets from the gitignored, bundled `Secrets.plist`.
///
/// Returns nil when the file is missing or the key is blank — the composition
/// root then falls back to the no-op transport, so the app always builds/runs
/// (e.g. a fresh checkout with no `Secrets.plist`). See `Secrets.example.plist`.
enum SecretsStore {

    struct PostHogSecrets {
        let apiKey: String
        let host: String
    }

    static func postHog(bundle: Bundle = .main) -> PostHogSecrets? {
        guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let apiKey = dict["POSTHOG_API_KEY"] as? String,
              !apiKey.isEmpty
        else { return nil }

        let host = (dict["POSTHOG_HOST"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? "https://eu.i.posthog.com"
        return PostHogSecrets(apiKey: apiKey, host: host)
    }
}
