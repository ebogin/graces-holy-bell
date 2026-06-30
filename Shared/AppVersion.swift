import Foundation

/// Marketing version + build number, read from the bundle's Info.plist.
///
/// Surfaced visibly in both apps (iPhone Settings footer, Watch log screen) so a
/// tester can confirm at a glance that the iPhone and the paired Watch are running
/// the *same* build — the Watch Sync protocol has no backward compatibility, so a
/// version skew between the two devices silently breaks reconciliation.
enum AppVersion {
    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    /// e.g. "v1.42 (6)"
    static var label: String { "v\(marketing) (\(build))" }
}
