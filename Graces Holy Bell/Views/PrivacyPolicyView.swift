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
    private let effectiveDate = "June 12, 2026"

    private let sections: [(heading: String, body: [String])] = [
        ("WHAT WE COLLECT", [
            "Nothing. Grace's Holy Bell has no servers and never sends your information anywhere. We don't ask for your name, email, contacts, or location, and there are no accounts or sign-ups."
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
            "Questions? Email eric@boginfactory.com."
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

                    Text("Grace's Holy Bell is built to respect your privacy. We do not collect, store, or share any personal data about you.")
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
