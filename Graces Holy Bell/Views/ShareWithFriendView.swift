import SwiftUI

/// "Share with a Friend" screen, presented as a sheet from SettingsView.
///
/// Shows this install's personal QR code in the app's LCD-green style. A friend
/// scans it (or opens the shared link) to reach the public waitlist form. The QR
/// is generated entirely on-device and encodes an anonymous referral code — see
/// `WaitlistLink` for how that code is created and stored.
struct ShareWithFriendView: View {

    @Environment(\.dismiss) private var dismiss

    private let shareURL = WaitlistLink.shareURL()
    @State private var qrImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {

            // ── Header bar: title + DONE ─────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                Text("SHARE WITH\nA FRIEND")
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
                .accessibilityIdentifier("share-done-button")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // ── Scrollable body ──────────────────────────────────────────
            ScrollView {
                VStack(spacing: 24) {

                    Text("Spread the word. Have a friend scan this code to join the waiting list for Grace's Holy Bell.")
                        .font(.pixelFont(10, relativeTo: .body))
                        .foregroundStyle(Color.lcdDark)
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    // QR card
                    Group {
                        if let qrImage {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .accessibilityLabel("Your personal waitlist QR code")
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        }
                    }
                    .frame(maxWidth: 260)
                    .padding(20)
                    .background(Color.lcdBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.lcdLogBorder, lineWidth: 4)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Share the link as text / via other apps
                    ShareLink(item: shareURL) {
                        Text("SHARE LINK")
                            .font(.pixelFont(10))
                            .foregroundStyle(Color.lcdThumbText)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.lcdSlider)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.lcdDark, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .accessibilityIdentifier("share-link-button")

                    Text("They'll land on a private signup page. There's no public list — see the Privacy Policy for details.")
                        .font(.pixelFont(8, relativeTo: .caption))
                        .foregroundStyle(Color.lcdMid)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
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
        .onAppear {
            if qrImage == nil {
                qrImage = QRCodeGenerator.image(
                    from: shareURL.absoluteString,
                    dark: .lcdDark,
                    light: .lcdBackground
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ShareWithFriendView()
}
