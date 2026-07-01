import SwiftUI
import WatchKit

private struct LogTableWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Compact pixel-art prayer log for Apple Watch.
/// Shown in both idle (previous session, read-only) and active (live last entry).
struct WatchPrayerLogView: View {

    let viewModel: WatchSessionViewModel
    let now: Date

    /// Fixed size for every row — always the readable default. Rows that
    /// don't fit side by side at this size switch to a stacked layout
    /// individually (see `WatchPrayerEntryRow.isStacked`) — the font size
    /// itself never changes.
    private static let fontSize: CGFloat = 8

    /// Best guess before the real measurement below lands, so the very first
    /// frame doesn't flash the wrong layout (GeometryReader's first pass can
    /// be an ideal-size probe rather than the settled frame).
    @State private var availableWidth: CGFloat = {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        // Screen's own 14pt margin (WatchLogView) + this box's 8pt padding, both sides.
        return screenWidth - 2 * 14 - 2 * 8
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(
                Array(viewModel.sortedEntries.enumerated()),
                id: \.element.id
            ) { index, entry in
                WatchPrayerEntryRow(
                    viewModel: viewModel,
                    entry: entry,
                    index: index,
                    isLastEntry: index == viewModel.sortedEntries.count - 1,
                    now: now,
                    fontSize: Self.fontSize,
                    availableWidth: availableWidth
                )
            }
        }
        .padding(8)
        .pixelBorder()
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: LogTableWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(LogTableWidthPreferenceKey.self) { width in
            if width > 0 { availableWidth = width }
        }
    }
}

struct WatchPrayerEntryRow: View {

    let viewModel: WatchSessionViewModel
    let entry: PrayerEvent
    let index: Int
    let isLastEntry: Bool
    let now: Date
    let fontSize: CGFloat
    let availableWidth: CGFloat

    private var timestampString: String {
        "#\(index + 1) \(TimeFormatter.wallClockString(from: entry.timestamp))"
    }

    private var durationString: String {
        let duration = isLastEntry && viewModel.appState == .active
            ? viewModel.duration(for: index, at: now)
            : viewModel.duration(for: index)
        return duration.map { DurationFormatter.string(from: $0) } ?? ""
    }

    /// This row's own fit check — timestamp + duration side by side at the
    /// fixed table size. Only rows that don't fit switch to the stacked
    /// layout; short rows on wide screens stay side by side. Press Start 2P
    /// is monospace with per-character advance ≈ its point size (see
    /// WatchLiveTimerView), so width is estimated by character count rather
    /// than a real text-measurement pass.
    private var isStacked: Bool {
        CGFloat(timestampString.count + durationString.count) * fontSize + 4 > availableWidth
    }

    var body: some View {
        if isStacked {
            VStack(alignment: .leading, spacing: 1) {
                timestampText
                    .frame(maxWidth: .infinity, alignment: .leading)
                durationView
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                timestampText
                Spacer(minLength: 4)
                durationView
            }
        }
    }

    private var timestampText: some View {
        Text.pixelTableText(timestampString, fontSize: fontSize)
            .foregroundStyle(Color.lcdDark)
            .lineLimit(1)
    }

    @ViewBuilder
    private var durationView: some View {
        if isLastEntry && viewModel.appState == .active {
            WatchLiveDurationText(viewModel: viewModel, entryIndex: index, now: now, fontSize: fontSize)
        } else if !durationString.isEmpty {
            Text.pixelTableText(durationString, fontSize: fontSize)
                .foregroundStyle(Color.lcdMid)
                .lineLimit(1)
        }
    }
}
