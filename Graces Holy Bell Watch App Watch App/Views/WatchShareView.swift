import SwiftUI

/// "JOIN US IN PRAYER" QR share screen — translated from Figma node 296:531.
///
/// Reached from the active screen's share button. Shows this watch's personal
/// waitlist QR, generated entirely on-device via the vendored pure-Swift encoder
/// (watchOS has no CoreImage). A friend scans it to join the waiting list. The
/// code is this watch's own anonymous referral code (see `WaitlistLink`); the
/// link is tagged `src=watch` so scans can be attributed to the watch surface.
struct WatchShareView: View {

    let viewModel: WatchSessionViewModel

    private let shareURL = WaitlistLink.shareURL(source: .watch)
    @State private var modules: [[Bool]]?

    var body: some View {
        VStack(spacing: 0) {

            // "Share the app" replaces the title/timer/caption header — sized to
            // fill one line (capped at 25pt, shrinks to fit narrower watches).
            Text("Share the app")
                .font(.pixelFont(25, relativeTo: .title2))
                .foregroundStyle(Color.lcdDark)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity)

            // QR card: prompt + code, inside the shared pixel border.
            VStack(spacing: 7) {
                // Square-wave blink, same rate as the start screen's
                // "SLIDE TO BEGIN" hint (driven by the same 0.5s timeline tick).
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Text("JOIN US IN PRAYER")
                        .font(.pixelFont(8, relativeTo: .headline))
                        .foregroundStyle(Color.lcdDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .opacity(Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
                }

                Group {
                    if let modules {
                        // Light modules use the card's own colour (#c0d0a8) so
                        // the QR background matches its container seamlessly.
                        WatchQRCodeView(modules: modules, light: .lcdLogInner)
                            .aspectRatio(1, contentMode: .fit)
                            .accessibilityLabel("Join us in prayer QR code")
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pixelBorder()
            .padding(.top, 4)

            // BACK button, lower-left. Sized to match the Log screen's BACK
            // button (21pt, same as the stop button) instead of the default 28.
            HStack {
                BackButton(action: { viewModel.showingShare = false }, size: 21)
                    .accessibilityIdentifier("watch-share-back-button")
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Metrics.cornerButtonInset)
            .padding(.top, 4)
        }
        // Same full-screen treatment as the other screens: clear the system
        // clock at the top, 14 horizontal, small margin above the bottom edge.
        .padding(.horizontal, 14)
        .padding(.top, DesignSystem.Metrics.clockClearance)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        // Analytics (additive): the Watch share/QR screen was opened. The QR
        // is shown immediately on this screen, so screen-opened and
        // qr-displayed fire together.
        .onAppear { viewModel.recordShareOpened() }
        .task {
            // Encode off the main actor — the pure-Swift encoder (Reed-Solomon
            // + 8-mask penalty scan) is heavy enough to jank the screen's
            // entrance animation on older watches.
            guard modules == nil else { return }
            let text = shareURL.absoluteString
            modules = await Task.detached(priority: .userInitiated) {
                WatchQRCodeView.matrix(for: text)
            }.value
        }
    }
}
