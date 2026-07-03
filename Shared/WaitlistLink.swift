import Foundation

/// Referral / waitlist link helper.
///
/// The app collects no personal data. To support the "Share with a Friend"
/// waitlist feature, each install mints a single anonymous referral code the
/// first time the share screen is opened. That code is stored only in
/// UserDefaults on this device and is never tied to a name, email, or account.
/// It is embedded in the shared short link so submissions — and scans, via
/// the Worker's click log — can be attributed to whoever shared the link.
enum WaitlistLink {

    /// Which device surface produced a share link, recorded as `src` on the URL
    /// so scans can be attributed to where the QR was shown (the phone's Settings
    /// share sheet vs. the watch's "Join us in prayer" screen). The referral
    /// `ref` code stays opaque and unchanged.
    enum ShareSource: String {
        case phone
        case watch
    }

    /// Public, green-styled waitlist form (served from `docs/` at boginfactory.com).
    /// Still the redirect target of the short link below, so it stays around
    /// for the confirmation-email share link (see the Worker's `sendEmails`).
    static let baseURL = "https://boginfactory.com/grace-waitlist.html"

    /// Stable short link the QR encodes. It never changes; where it redirects
    /// (waitlist page pre-launch, App Store post-approval) flips server-side
    /// via the Worker's `REDIRECT_URL` env var — see
    /// planning/referral-click-tracking-spec.md.
    private static let shortLinkBaseURL = "https://boginfactory.com/r"

    private static let codeKey = "waitlistReferralCode"

    /// Stable anonymous referral code for this install, minted once and persisted.
    static var referralCode: String {
        if let existing = UserDefaults.standard.string(forKey: codeKey) {
            return existing
        }
        let code = newCode()
        UserDefaults.standard.set(code, forKey: codeKey)
        return code
    }

    /// The full URL a friend opens (or scans) to reach the waitlist form,
    /// carrying this install's referral code and the sharing `source` surface.
    static func shareURL(for code: String = referralCode,
                         source: ShareSource = .phone) -> URL {
        var components = URLComponents(string: shortLinkBaseURL + "/" + code)!
        components.queryItems = [
            URLQueryItem(name: "src", value: source.rawValue),
        ]
        return components.url!
    }

    /// 8-character lowercase code drawn from an unambiguous alphabet
    /// (no 0/o/1/l/i to keep it readable if ever transcribed).
    private static func newCode() -> String {
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }
}
