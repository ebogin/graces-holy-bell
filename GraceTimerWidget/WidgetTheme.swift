import SwiftUI

// MARK: - LCD Color Palette (widget-local copy of the app's Theme.swift)
// The widget extension can't see the app target's Theme, so the palette is
// duplicated here. Keep hex values in sync with "Graces Holy Bell/Theme.swift".
extension Color {
    /// Main screen background — pale LCD green
    static let lcdBackground  = Color(hex: "#c8d8b0")
    /// Slider/button track fill (medium green)
    static let lcdSlider      = Color(hex: "#8aaa6a")
    /// Primary text and borders — near-black olive
    static let lcdDark        = Color(hex: "#1a2a0a")
    /// Secondary / caption text — dark olive green
    static let lcdMid         = Color(hex: "#4a6a3a")
    /// Screen title text — medium olive
    static let lcdTitle       = Color(hex: "#5f7c4d")
    /// Text that sits on a dark (lcdDark) background
    static let lcdThumbText   = Color(hex: "#c8d8b0")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Press Start 2P Font
extension Font {
    /// Press Start 2P pixel font at a fixed size (widgets don't track Dynamic Type).
    static func pixelFont(_ size: CGFloat) -> Font {
        Font.custom("PressStart2P-Regular", size: size)
    }
}
