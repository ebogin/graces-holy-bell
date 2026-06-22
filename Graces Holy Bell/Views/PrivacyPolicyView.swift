import SwiftUI

/// In-app privacy policy, presented as a sheet from SettingsView.
///
/// Plain-language statement that the app collects no data. Keep the copy here in
/// sync with the public web version (docs/graces-privacy-policy.html) and the App Store
/// Connect "App Privacy" answers ("Data Not Collected").
///
/// ───────────────────────────────────────────────────────────────────────────
/// MAINTENANCE NOTE (for any human or AI editing this policy):
/// This policy is also published publicly at:
///     https://boginfactory.com/graces-privacy-policy.html
/// (served from the source file `docs/graces-privacy-policy.html` in this repo).
///
/// If you change the privacy policy text below, you MUST also update that
/// hosted webpage so the in-app and public versions stay identical — update
/// `docs/graces-privacy-policy.html` and ensure the deployed page at the URL above
/// reflects the same wording and effective date.
/// ───────────────────────────────────────────────────────────────────────────
struct PrivacyPolicyView: View {

    @Environment(\.dismiss) private var dismiss

    /// Last time the policy text changed. Update alongside the web version.
    private let effectiveDate = "June 22, 2026"

    private let sections: [(heading: String, body: [String])] = [
        ("WHAT WE COLLECT", [
            "The app itself collects nothing. Grace's Holy Bell has no servers and never sends your information anywhere. We don't ask for your name, email, contacts, or location, and there are no accounts or sign-ups.",
            "The one exception is our optional waitlist signup — see \"Waitlist Signup\" below. It lives on our website, separate from the app, and only ever has the information you choose to type into it."
        ]),
        ("WAITLIST SIGNUP", [
            "If you use \"Share with a Friend\" and a friend opens your link, it takes them to a signup page on our website. This is the only place the project collects information.",
            "The form asks for an email, name, country, and phone number, and all of them are optional. If you check the box authorizing it, we use your phone number to send SMS text messages about the app; message and data rates may apply, and we keep a record of that consent. We also store the anonymous referral code from the link that was used, so we know who to thank for the introduction — this code is not tied to your identity in the app.",
            "What's submitted is stored privately and used only to send a confirmation, to reach out about the app's release, and — if you authorized it — to text you about the app. There is no public waiting list, and we never sell or share it with advertisers. To be removed, or to stop the texts, email gracesholybell@boginfactory.com."
        ]),
        ("WHAT STAYS ON YOUR DEVICE", [
            "Your prayer logs and Amen Alarm settings are saved only on your device.",
            "If you use the Apple Watch app, this information syncs privately between your iPhone and Watch over Apple's local device-to-device connection. It never leaves your devices, and we can't see it."
        ]),
        ("NOTIFICATIONS", [
            "If you turn on the Amen Alarm, the app schedules local notifications on your iPhone and/or Apple Watch. These are created and delivered entirely on your device."
        ]),
        ("THIRD PARTIES", [
            "The app includes no third-party analytics, advertising, or tracking tools. We don't share data with anyone — because we don't have any to share."
        ]),
        ("TRACKING", [
            "We do not track you across other apps or websites."
        ]),
        ("CHILDREN", [
            "The app collects no data from anyone, including children."
        ]),
        ("CHANGES", [
            "If this policy ever changes — for example, if a future version adds a feature that needs data — we'll update this page and ask for your consent where required."
        ]),
        ("CONTACT", [
            "Questions? Email gracesholybell@boginfactory.com."
        ])
    ]

    var body: some View {
        VStack(spacing: 0) {

            // ── Header bar: title + DONE ─────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                Text("PRIVACY\nPOLICY")
                    .font(.pixelFont(16, relativeTo: .title))
                    .foregroundStyle(Color.lcdDark)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(.pixelFont(9))
                        .foregroundStyle(Color.lcdThumbText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.lcdSlider)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.lcdDark, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("privacy-done-button")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // ── Scrollable policy body ───────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {

                    Text("Grace's Holy Bell is built to respect your privacy. The app does not collect, store, or share any personal data about you. The one exception is our optional waitlist signup, described below.")
                        .font(.pixelFont(10, relativeTo: .body))
                        .foregroundStyle(Color.lcdDark)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(sections, id: \.heading) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.heading)
                                .font(.pixelFont(11, relativeTo: .headline))
                                .foregroundStyle(Color.lcdTitle)

                            ForEach(section.body, id: \.self) { paragraph in
                                Text(paragraph)
                                    .font(.pixelFont(9, relativeTo: .body))
                                    .foregroundStyle(Color.lcdMid)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Effective \(effectiveDate)")
                        .font(.pixelFont(8, relativeTo: .caption))
                        .foregroundStyle(Color.lcdMid)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.lcdBackgroundLight, Color.lcdBackgroundDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Preview

#Preview {
    PrivacyPolicyView()
}
