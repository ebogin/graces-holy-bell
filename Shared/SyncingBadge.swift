import SwiftUI

/// Small "SYNCING…" pill shown only while a cross-device reconcile is taking a
/// beat. The fast path clears the flag before this ever appears (the
/// connectivity layer delays showing it), and it is also hard-bounded so it can
/// never stick on screen. Compiled into both the iPhone and Watch targets;
/// `fontSize` lets each platform size it to its own type scale.
struct SyncingBadge: View {
    var fontSize: CGFloat = 8

    var body: some View {
        Text("SYNCING…")
            .font(.pixelFont(fontSize))
            .foregroundStyle(Color.lcdMid)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.lcdLogInner.opacity(0.92))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.lcdLogBorder, lineWidth: 1))
            .transition(.opacity)
    }
}
