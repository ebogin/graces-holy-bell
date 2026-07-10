import SwiftUI

/// Renders a `WelcomeMessage`'s blocks in the LCD style, used both for the
/// idle-screen welcome text and (via `detailMaxImageHeight`) its optional
/// tap-through detail sheet. See RemoteConfig.swift for the block schema.
struct WelcomeMessageView: View {

    let message: WelcomeMessage
    /// Idle-screen context caps runaway remote content so it can't crowd the
    /// fixed "SLIDE TO BEGIN" blinker below it; the detail sheet relaxes both.
    var maxImageHeight: CGFloat = 80
    var textLineLimit: Int? = 8

    @State private var showDetail = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(message.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .sheet(isPresented: $showDetail) {
            if let detail = message.detail {
                WelcomeDetailView(detail: detail)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: WelcomeBlock) -> some View {
        switch block {
        case .text(let value, let align, let size, let color):
            Text(value)
                .font(.pixelFont(size.points, relativeTo: .body))
                .foregroundStyle(color.color)
                .multilineTextAlignment(align.textAlignment)
                .lineSpacing(3)
                .lineLimit(textLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: align.frameAlignment)

        case .image(let url, let caption):
            VStack(spacing: 4) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Color.clear
                }
                .frame(maxHeight: maxImageHeight)

                if let caption {
                    Text(caption)
                        .font(.pixelFont(8, relativeTo: .caption))
                        .foregroundStyle(Color.lcdMid)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)

        case .link(let label, let destination):
            Button {
                switch destination {
                case .detail:
                    guard message.detail != nil else { return }
                    showDetail = true
                case .url(let url):
                    openURL(url)
                }
            } label: {
                Text("\(label) >")
                    .font(.pixelFont(10, relativeTo: .body))
                    .foregroundStyle(Color.lcdDark)
            }
            .buttonStyle(.plain)
            .disabled(isDetailLinkWithNoDetail(destination))

        case .unknown:
            EmptyView()
        }
    }

    private func isDetailLinkWithNoDetail(_ destination: WelcomeLinkDestination) -> Bool {
        if case .detail = destination {
            return message.detail == nil
        }
        return false
    }
}

private extension WelcomeTextAlign {
    var textAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

/// Full-height sheet for a message's `detail` content — where long-form
/// content (e.g. a watch-install diagram) lives, since the idle screen's
/// middle region is too small for it.
private struct WelcomeDetailView: View {

    let detail: WelcomeDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(detail.title ?? "")
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
                .accessibilityIdentifier("welcome-detail-done-button")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            ScrollView {
                WelcomeMessageView(
                    message: WelcomeMessage(id: nil, audience: nil, blocks: detail.blocks, detail: nil),
                    maxImageHeight: 260,
                    textLineLimit: nil
                )
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

#Preview("Text-only") {
    WelcomeMessageView(
        message: WelcomeMessage(
            id: "preview",
            audience: "all",
            blocks: [
                .text(value: "Welcome to your favorite app to time prayer duration.", align: .leading, size: .body, color: .dark)
            ],
            detail: nil
        )
    )
    .padding()
    .background(Color.lcdBackground)
}

#Preview("With detail link") {
    WelcomeMessageView(
        message: WelcomeMessage(
            id: "preview-watch",
            audience: "watch_not_installed",
            blocks: [
                .text(value: "GET GRACE ON YOUR WRIST", align: .center, size: .large, color: .dark),
                .text(value: "Prayers sync from your Apple Watch automatically.", align: .leading, size: .body, color: .dark),
                .link(label: "HOW TO INSTALL", destination: .detail)
            ],
            detail: WelcomeDetail(
                title: "INSTALL ON APPLE WATCH",
                blocks: [
                    .text(value: "1. Open the Watch app on your iPhone.\n2. Scroll to Available Apps.\n3. Tap Install next to Grace's Holy Bell.", align: .leading, size: .body, color: .dark)
                ]
            )
        )
    )
    .padding()
    .background(Color.lcdBackground)
}
