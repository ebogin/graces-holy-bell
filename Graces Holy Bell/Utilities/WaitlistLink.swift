import Foundation

/// Referral / waitlist link helper.
///
/// The app collects no personal data. To support the "Share with a Friend"
/// waitlist feature, each install mints a single anonymous referral code the
/// first time the share screen is opened. That code is stored only in
/// UserDefaults on this device and is never tied to a name, email, or account.
/// It is appended to the public waitlist URL so submissions can be attributed
/// to whoever shared the link.
enum WaitlistLink {

    /// Public, green-styled waitlist form (served from `docs/` at boginfactory.com).
    static let baseURL = "https://boginfactory.com/grace-waitlist.html"

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
    /// carrying this install's referral code.
    static func shareURL(for code: String = referralCode) -> URL {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: "ref", value: code)]
        return components.url!
    }

    /// 8-character lowercase code drawn from an unambiguous alphabet
    /// (no 0/o/1/l/i to keep it readable if ever transcribed).
    private static func newCode() -> String {
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }
}
