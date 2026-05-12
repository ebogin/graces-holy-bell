import SwiftUI

// MARK: - LCD Color Palette
// Game Boy / Tamagotchi green LCD aesthetic
extension Color {
    /// Main screen background — pale LCD green
    static let lcdBackground  = Color(hex: "#c8d8b0")
    /// Slightly lighter variant used for iPhone gradient top
    static let lcdBackgroundLight = Color(hex: "#d4e4bc")
    /// Slightly darker variant used for iPhone gradient bottom
    static let lcdBackgroundDark  = Color(hex: "#c4d4ac")
    /// Log container inner fill
    static let lcdLogInner    = Color(hex: "#c0d0a8")
    /// Log container outer border tint
    static let lcdLogBorder   = Color(hex: "#a0b080")
    /// Slider/button track fill (medium green)
    static let lcdSlider      = Color(hex: "#8aaa6a")
    /// Primary text and borders — near-black olive
    static let lcdDark        = Color(hex: "#1a2a0a")
    /// Secondary / caption text — dark olive green
    static let lcdMid         = Color(hex: "#4a6a3a")
    /// Text that sits on a dark (lcdDark) background
    static let lcdThumbText   = Color(hex: "#c8d8b0")
    /// Subtle screen edge border
    static let lcdBorder      = Color(hex: "#9aaa8a")

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
    /// Press Start 2P pixel font at the given size.
    /// Falls back to monospaced system font if the custom font isn't registered yet.
    static func pixelFont(_ size: CGFloat) -> Font {
        Font.custom("PressStart2P-Regular", size: size)
    }
}

// MARK: - LCD Background Gradient (iPhone)
extension ShapeStyle where Self == LinearGradient {
    static var lcdGradient: LinearGradient {
        LinearGradient(
            colors: [Color.lcdBackgroundLight, Color.lcdBackgroundDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Octagon Shape (STOP button)
struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cut = w * 0.29          // ~29% corner cut for an even octagon
        var path = Path()
        path.move(to:    CGPoint(x: cut,     y: 0))
        path.addLine(to: CGPoint(x: w - cut, y: 0))
        path.addLine(to: CGPoint(x: w,       y: cut))
        path.addLine(to: CGPoint(x: w,       y: h - cut))
        path.addLine(to: CGPoint(x: w - cut, y: h))
        path.addLine(to: CGPoint(x: cut,     y: h))
        path.addLine(to: CGPoint(x: 0,       y: h - cut))
        path.addLine(to: CGPoint(x: 0,       y: cut))
        path.closeSubpath()
        return path
    }
}

// MARK: - Pixel Border Modifier
/// Draws the double-border box used for the prayer log container.
struct PixelBorderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.lcdLogInner)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.lcdLogBorder, lineWidth: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

extension View {
    func pixelBorder() -> some View {
        modifier(PixelBorderModifier())
    }
}
