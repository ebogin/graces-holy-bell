import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity for an active prayer session.
///
/// Renders the "since last prayer" count-up timer on the Lock Screen, in the
/// Dynamic Island, and (via the .small supplemental family) in the watchOS
/// Smart Stack — all in the app's LCD-green / pixel-font look. The timer uses
/// `Text(timerInterval:)` so the system ticks it without any app updates.
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
                    BellGlyph(size: 22, color: .lcdThumbText)
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
                BellGlyph(size: 14, color: .lcdThumbText)
            } compactTrailing: {
                TimerText(since: context.state.lastPrayerAt)
                    .font(.pixelFont(9))
                    .foregroundStyle(Color.lcdThumbText)
                    .frame(maxWidth: 58)
            } minimal: {
                BellGlyph(size: 13, color: .lcdThumbText)
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
                    BellGlyph(size: 14, color: .lcdDark)
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
private struct TimerText: View {
    let since: Date

    var body: some View {
        Text(timerInterval: since...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

/// Bell rendered as an SF Symbol tinted to the LCD palette — reads cleanly at
/// Dynamic Island sizes where the pixel font would smear.
private struct BellGlyph: View {
    let size: CGFloat
    let color: Color

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
    }
}
