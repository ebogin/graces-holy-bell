import SwiftUI

/// The title + live timer + "SINCE LAST PRAYER" header block shown at the top of
/// the active and share screens.
///
/// Extracted so every screen renders it at the EXACT same size — paired with the
/// same outer paddings (`DesignSystem.Metrics.clockClearance` top, 14 horizontal),
/// the header lands in an identical position on each screen, so switching to the
/// share screen reads as "the figure + slider were swapped for the QR frame."
struct WatchSessionHeader: View {

    let viewModel: WatchSessionViewModel
    let now: Date

    var body: some View {
        VStack(spacing: 2) {
            Text("GRACE'S HOLY BELL")
                .font(.pixelFont(8))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)

            WatchLiveTimerView(viewModel: viewModel, now: now)
        }
        .frame(maxWidth: .infinity)
    }
}
