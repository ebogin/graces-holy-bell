import SwiftUI

/// In-app privacy policy, presented as a sheet from SettingsView.
///
/// Plain-language statement: prayer logs stay on-device; the only thing the app
/// sends is optional, anonymous PostHog usage analytics (consent-gated, off in
/// the EU/UK/EEA until opt-in). Keep the copy here in sync with the public web
/// version (docs/graces-privacy-policy.html) and the App Store Connect "App
/// Privacy" answers (Identifiers + Usage Data, used for Analytics, not linked to
/// identity, not used for tracking).
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
    private let effectiveDate = "June 27, 2026"

    private let sections: [(heading: String, body: [String])] = [
        ("WHAT WE COLLECT", [
            "On your device, the app keeps your prayer logs and Amen Alarm settings (see \"What Stays on Your Device\"). There are no accounts and no sign-ups.",
            "The only information the app sends off your device is anonymous usage analytics, and only while analytics are turned on — see \"Anonymous Analytics\" below. We don't ask for your name, email, contacts, or GPS location. The one place we collect contact details is our optional waitlist signup — see \"Waitlist Signup\" below."
        ]),
        ("ANONYMOUS ANALYTICS", [
            "To learn how the app is used — and, true to its purpose, whether it actually helps people stay mindful of how often and how long they pray — we collect anonymous usage analytics through PostHog, an analytics service. The data for this app is processed on PostHog's servers in the European Union.",
            "It's tied only to a random ID created on your device when you install the app — not your name, Apple ID, email, or phone number — and it isn't linked to your identity. We record events like when a prayer session starts and ends, roughly how long sessions last and how they're spaced (in broad time ranges), which features you use, and your app, device, and operating-system version. We never record the content of your prayers.",
            "When your device sends this data, PostHog's servers can see its IP address and use it to estimate an approximate location, such as your country or city. We don't use this to identify you, and you can stop all of it by turning analytics off.",
            "You control this in Settings, under Privacy. Outside the European Union, the United Kingdom, and the EEA, analytics are on by default and you can opt out at any time. Within them, analytics stay off until you choose to opt in."
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
            "The app uses one third-party service: PostHog, for the anonymous analytics described above. It includes no advertising and no cross-app tracking tools. Our waitlist signup (on our website) uses Resend to send its confirmation email. We don't sell your information or share it with advertisers."
        ]),
        ("TRACKING", [
            "We do not track you across other apps or websites."
        ]),
        ("CHILDREN", [
            "The app isn't directed at children, and the analytics it collects are anonymous and not tied to anyone's identity. We don't knowingly collect personal information from children."
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

                    Text("Grace's Holy Bell is built to respect your privacy. Your prayer logs stay on your device. The only thing the app sends anywhere is optional, anonymous usage analytics — which you can turn off at any time. It never records the content of your prayers, and never your name, email, or account. Two optional things are described below: the anonymous analytics, and our waitlist signup.")
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
