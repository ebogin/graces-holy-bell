import SwiftUI
import SwiftData

/// Pixel-art prayer log container (iPhone).
///
/// Displays entries in a double-bordered LCD-green box.
/// Each row: "#N HH:MMam" on the left, duration on the right.
/// The last entry shows a live-updating duration during an active session.
/// LONG-PRESSING a row (with haptic confirm) opens PrayerDetailSheet
/// (edit time / intention / delete) — a stray tap never opens or mutates
/// anything, per the no-accidental-log-damage tenet.
struct PrayerLogView: View {

    let viewModel: SessionViewModel
    let now: Date
    /// Row long-pressed — the parent presents the detail sheet.
    var onSelectEntry: ((PrayerEntry) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(
                    Array(viewModel.sortedEntries.enumerated()),
                    id: \.element.persistentModelID
                ) { index, entry in
                    PrayerEntryRow(
                        viewModel: viewModel,
                        entry: entry,
                        index: index,
                        isLastEntry: index == viewModel.sortedEntries.count - 1,
                        now: now,
                        onSelect: onSelectEntry
                    )

                    if index < viewModel.sortedEntries.count - 1 {
                        Divider()
                            .overlay(Color.lcdMid.opacity(0.4))
                    }
                }
            }
            .padding(12)
        }
        .pixelBorder()
    }
}

/// A single prayer row — compact format: "#N HH:MMam [note]   duration >"
struct PrayerEntryRow: View {

    let viewModel: SessionViewModel
    let entry: PrayerEntry
    let index: Int
    let isLastEntry: Bool
    let now: Date
    var onSelect: ((PrayerEntry) -> Void)? = nil

    /// Row squeezes slightly while the long-press builds — the visual cue that
    /// rows respond to holding.
    @State private var isPressing = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("#\(index + 1)  \(TimeFormatter.wallClockString(from: entry.timestamp))")
                .font(.pixelFont(9))
                .foregroundStyle(Color.lcdDark)

            // Subtle marker: this prayer has an intention attached. Baseline
            // guide = icon bottom, so with the icon sized to the 9pt cap height
            // its TOP aligns with the top of the time text.
            if entry.note != nil {
                NoteGlyphIcon(size: 9, color: .lcdMid)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
                    .accessibilityLabel("Has intention")
            }

            Spacer(minLength: 8)

            if isLastEntry && viewModel.appState == .active {
                LiveDurationText(viewModel: viewModel, entryIndex: index, now: now)
            } else {
                if let duration = viewModel.duration(for: index) {
                    Text(DurationFormatter.string(from: duration))
                        .font(.pixelFont(9))
                        .foregroundStyle(Color.lcdMid)
                }
            }

            // Editability cue — same ">" affordance the Settings rows use.
            if onSelect != nil {
                Text(">")
                    .font(.pixelFont(7))
                    .foregroundStyle(Color.lcdMid.opacity(0.7))
                    .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isPressing ? 0.97 : 1)
        .opacity(isPressing ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.15), value: isPressing)
        .onLongPressGesture(minimumDuration: 0.4) {
            guard let onSelect else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSelect(entry)
        } onPressingChanged: { pressing in
            isPressing = pressing && onSelect != nil
        }
        .accessibilityIdentifier("prayer-row-\(index + 1)")
    }
}
