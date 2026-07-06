import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity for an active prayer session.
///
/// Renders the "since last prayer" count-up timer on the Lock Screen, in the
/// Dynamic Island, and (via the .small supplemental family) in the watchOS
/// Smart Stack — all in the app's LCD-green / pixel-font look. The timer is
/// a system-ticking live text, so it advances without any app updates.
struct PrayerLiveActivityWidget: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            // Lock Screen / StandBy banner (and watch Smart Stack via .small).
            PrayerLockScreenView(state: context.state)
                .activityBackgroundTint(Color.lcdBackground)
                .activitySystemActionForegroundColor(Color.lcdDark)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press the island)
                DynamicIslandExpandedRegion(.leading) {
                    BellGlyph(size: 30, color: .lcdThumbText)
                        .padding(.leading, 6)
                        .padding(.top, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.prayerCount)X")
                        .font(.pixelFont(14))
                        .foregroundStyle(Color.lcdThumbText)
                        .padding(.trailing, 6)
                        .padding(.top, 12)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 5) {
                        TimerText(since: context.state.lastPrayerAt)
                            .font(.pixelFont(22))
                            .foregroundStyle(Color.lcdThumbText)
                        Text("SINCE LAST PRAYER")
                            .font(.pixelFont(7))
                            .foregroundStyle(Color.lcdSlider)
                    }
                }
            } compactLeading: {
                BellGlyph(size: 20, color: .lcdThumbText)
            } compactTrailing: {
                TimerText(since: context.state.lastPrayerAt)
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdThumbText)
                    .frame(maxWidth: 74)
            } minimal: {
                BellGlyph(size: 18, color: .lcdThumbText)
            }
            .keylineTint(Color.lcdSlider)
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Lock Screen / Smart Stack view

private struct PrayerLockScreenView: View {

    let state: PrayerActivityAttributes.ContentState
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        switch activityFamily {
        case .small:
            // watchOS Smart Stack — tighter spacing, smaller type.
            VStack(spacing: 4) {
                TimerText(since: state.lastPrayerAt)
                    .font(.pixelFont(18))
                    .foregroundStyle(Color.lcdDark)
                Text("SINCE LAST PRAYER")
                    .font(.pixelFont(6))
                    .foregroundStyle(Color.lcdMid)
                Text("PRAYERS: \(state.prayerCount)")
                    .font(.pixelFont(6))
                    .foregroundStyle(Color.lcdMid)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

        default:
            // iPhone Lock Screen banner.
            VStack(spacing: 7) {
                HStack {
                    Text("GRACE'S HOLY BELL")
                        .font(.pixelFont(9))
                        .foregroundStyle(Color.lcdTitle)
                    Spacer()
                    BellGlyph(size: 20, color: .lcdDark)
                }
                TimerText(since: state.lastPrayerAt)
                    .font(.pixelFont(26))
                    .foregroundStyle(Color.lcdDark)
                    .frame(maxWidth: .infinity)
                HStack {
                    Text("SINCE LAST PRAYER")
                        .font(.pixelFont(7))
                        .foregroundStyle(Color.lcdMid)
                    Spacer()
                    Text("PRAYERS: \(state.prayerCount)")
                        .font(.pixelFont(7))
                        .foregroundStyle(Color.lcdMid)
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Shared pieces

/// System-ticking count-up timer — no app process needed to advance it.
///
/// Always shows HH:MM:SS, zero-padded. `Text(timerInterval:)` and the timer/
/// stopwatch system styles all drop the hours field below one hour, so this
/// uses `Duration.TimeFormatStyle` (the one live-tickable style with
/// `padHourToLength`) over a `durationOffset` time data source.
///
/// The dimmed (always-on) render can't tick that data source and shows a
/// "__:__:__" placeholder instead, so that pass gets the elapsed time frozen
/// at the moment the system took the dimmed snapshot.
private struct TimerText: View {
    let since: Date
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            if isLuminanceReduced {
                Text(frozenElapsed)
            } else {
                Text(
                    .durationOffset(to: since),
                    format: .time(pattern: .hourMinuteSecond(padHourToLength: 2))
                )
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private var frozenElapsed: String {
        Duration.seconds(max(Date.now.timeIntervalSince(since), 0))
            .formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2)))
    }
}

/// Praying-hands silhouette (from the 🙏 emoji) rendered as a template image
/// so it takes the LCD-green tint on every surface.
private struct BellGlyph: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Image("PrayingHands")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}
