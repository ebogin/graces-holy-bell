import SwiftUI

// Shared LCD color palette for the Watch target.
// Mirrors the iOS Theme.swift — kept separate so each target compiles independently.

extension Color {
    static let lcdBackground      = Color(hex: "#c8d8b0")
    static let lcdBackgroundLight = Color(hex: "#d4e4bc")
    static let lcdBackgroundDark  = Color(hex: "#c4d4ac")
    static let lcdLogInner        = Color(hex: "#c0d0a8")
    static let lcdLogBorder       = Color(hex: "#a0b080")
    static let lcdSlider          = Color(hex: "#8aaa6a")
    static let lcdProgress        = Color(hex: "#6a8a4a")
    static let lcdDark            = Color(hex: "#1a2a0a")
    static let lcdMid             = Color(hex: "#4a6a3a")
    static let lcdThumbText       = Color(hex: "#c8d8b0")
    static let lcdBorder          = Color(hex: "#9aaa8a")

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

extension Font {
    /// Press Start 2P pixel font at the given size, scaled with Dynamic Type.
    /// `style` controls how aggressively the size tracks the user's text-size
    /// setting (e.g. `.title` scales more than `.caption2`).
    static func pixelFont(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom("PressStart2P-Regular", size: size, relativeTo: style)
    }
}

extension Text {
    /// Builds table text with every literal space's trailing gap narrowed by
    /// 20% of `fontSize`. Press Start 2P is monospace with per-character
    /// advance ≈ its point size, so this narrows just the word-gaps — not
    /// the spacing between other characters — by about 20%.
    static func pixelTableText(_ string: String, fontSize: CGFloat) -> Text {
        var attributed = AttributedString(string)
        let kern = -0.2 * fontSize
        for index in attributed.characters.indices where attributed.characters[index] == " " {
            let next = attributed.index(afterCharacter: index)
            attributed[index..<next].kern = kern
        }
        return Text(attributed).font(.pixelFont(fontSize))
    }
}

struct Octagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let cut = w * 0.29
        var p = Path()
        p.move(to:    CGPoint(x: cut,     y: 0))
        p.addLine(to: CGPoint(x: w - cut, y: 0))
        p.addLine(to: CGPoint(x: w,       y: cut))
        p.addLine(to: CGPoint(x: w,       y: h - cut))
        p.addLine(to: CGPoint(x: w - cut, y: h))
        p.addLine(to: CGPoint(x: cut,     y: h))
        p.addLine(to: CGPoint(x: 0,       y: h - cut))
        p.addLine(to: CGPoint(x: 0,       y: cut))
        p.closeSubpath()
        return p
    }
}

struct PixelBorderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.lcdLogInner)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.lcdLogBorder, lineWidth: 3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

extension View {
    func pixelBorder() -> some View {
        modifier(PixelBorderModifier())
    }
}
