import SwiftUI

/// First-launch EU/EEA/UK opt-in consent screen (shown only when consent is
/// `pending`). Anonymous-analytics opt-in, in the app's LCD/pixel style. Both
/// choices carry equal weight (no dark patterns), as EU consent requires.
struct AnalyticsConsentBanner: View {

    let consent: AnalyticsConsent
    @State private var showPrivacyPolicy = false

    var body: some View {
        ZStack {
            Color.lcdBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text("EU PRIVACY NOTICE")
                        .font(.pixelFont(13))
                        .foregroundStyle(Color.lcdDark)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("To help improve Grace's Holy Bell, the app can share anonymous usage patterns — such as how often and how long you pray — grouped into broad ranges, never the exact numbers.")

                        Text("What \"anonymous\" means here: we don't have your name, email, or any personal details. The data is linked only to a random ID generated on your device, so it can't be connected to you as a person. Your prayers themselves are never recorded.")

                        Text("You're always in control — change this whenever you like in Settings.")
                    }
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdMid)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        Text("Read our Privacy Policy")
                            .font(.pixelFont(9))
                            .foregroundStyle(Color.lcdTitle)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("consent-privacy-policy-link")

                    VStack(spacing: 10) {
                        choiceButton("ALLOW", filled: true) { consent.grant() }
                        choiceButton("NO THANKS", filled: false) { consent.deny() }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }

    @ViewBuilder
    private func choiceButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.pixelFont(10))
                .foregroundStyle(filled ? Color.lcdThumbText : Color.lcdDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(filled ? Color.lcdProgress : Color.lcdLogInner)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.lcdDark, lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("consent-\(filled ? "allow" : "deny")")
    }
}

#Preview {
    AnalyticsConsentBanner(
        consent: AnalyticsConsent(store: UserDefaultsConsentStore(), locale: Locale(identifier: "de_DE"))
    )
}
