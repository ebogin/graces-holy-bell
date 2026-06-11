import SwiftUI

enum DesignSystem {

    // MARK: - Colors
    enum Colors {
        // Backgrounds
        static let background      = Color(hex: "#c8d8b0")
        static let backgroundLight = Color(hex: "#d4e4bc")
        static let backgroundDark  = Color(hex: "#c4d4ac")

        // Surfaces
        static let surfaceInner    = Color(hex: "#c0d0a8")
        static let surfaceBorder   = Color(hex: "#a0b080")

        // Interactive
        static let interactive     = Color(hex: "#8aaa6a")

        // Text
        static let textPrimary     = Color(hex: "#1a2a0a")
        static let textSecondary   = Color(hex: "#4a6a3a")
        static let textOnDark      = Color(hex: "#c8d8b0")

        // Border
        static let border          = Color(hex: "#9aaa8a")
    }

    // MARK: - Typography
    // Each role scales with the user's Dynamic Type setting via `relativeTo`.
    enum Typography {
        static let caption:      Font = pixelFont(7,  relativeTo: .caption2)
        static let bodySmall:    Font = pixelFont(8,  relativeTo: .footnote)
        static let body:         Font = pixelFont(9,  relativeTo: .body)
        static let bodyLarge:    Font = pixelFont(10, relativeTo: .body)
        static let subheadline:  Font = pixelFont(11, relativeTo: .subheadline)
        static let headline:     Font = pixelFont(12, relativeTo: .headline)
        static let display:      Font = pixelFont(28, relativeTo: .largeTitle)

        static func pixelFont(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
            Font.custom("PressStart2P-Regular", size: size, relativeTo: style)
        }
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 6
        static let md:  CGFloat = 8
        static let lg:  CGFloat = 12
        static let xl:  CGFloat = 16
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 3
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
    }

    // MARK: - Gradients
    enum Gradients {
        static var lcdBackground: LinearGradient {
            LinearGradient(
                colors: [Colors.backgroundLight, Colors.backgroundDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
