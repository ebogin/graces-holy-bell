import SwiftUI

/// Lower-left "share" affordance on the active screen. Tapping opens the
/// "JOIN US IN PRAYER" QR screen.
struct ShareButton: View {
    let action: () -> Void
    // Sits just under the LOG badge's rendered height so the bottom-row
    // affordances read as balanced.
    var size: CGFloat = 16

    var body: some View {
        Button(action: action) {
            ShareIconShape()
                .fill(Color.lcdDark)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}
