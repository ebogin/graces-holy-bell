import SwiftUI
import WatchKit

enum DesignSystem {

    // MARK: - Metrics
    enum Metrics {
        /// Vertical band reserved for the system clock, which watchOS always
        /// draws in the top-right corner. The navigation bar is hidden (so the
        /// safe area does not account for the clock); ~14% of screen height
        /// clears the clock on every watch size (measured: clock bottom ≈ 13.7%
        /// of screen height on 40mm) while scaling proportionally on larger models.
        static var clockClearance: CGFloat {
            WKInterfaceDevice.current().screenBounds.height * 0.14
        }

        /// Tunable scale for the corner-button inset. Multiplied by how many points a
        /// model's display corner radius exceeds the SE baseline (28pt). Set by eye in
        /// the simulator on the Series 11 and Ultra — see the tuning loop in the plan.
        /// Starting point: 0.7 (→ Ultra 3 ≈ 20pt, Series 11 46mm ≈ 15pt).
        static let cornerInsetScale: CGFloat = 0.7

        /// Documented display corner radius (points) keyed by screen width. The SE
        /// baseline is 28. watchOS exposes no corner-radius API, so we look it up from
        /// screenBounds (a stable per-model constant). Unknown widths fall back to 28
        /// (→ zero inset), which is safe.
        static var displayCornerRadius: CGFloat {
            switch WKInterfaceDevice.current().screenBounds.width {
            case 161...163: return 28   // 40mm (SE 1/2/3, Series 4/5/6)
            case 183...185: return 34   // 44mm (SE 1/2/3, Series 4/5/6)
            case 175...177: return 38   // 41mm (Series 7/8/9)
            case 197...199: return 41   // 45mm (Series 7/8/9)
            case 186...188: return 45   // 42mm (Series 10/11)
            case 207...209: return 49   // 46mm (Series 10/11)
            case 204...206: return 54   // 49mm (Ultra 1/2)
            case 210...213: return 56   // 49mm (Ultra 3)
            default:        return 28   // older/square + anything unknown → no inset
            }
        }

        /// Horizontal shift applied to each lower-left / lower-right corner button so it
        /// clears the rounded display corner. Zero at the SE baseline; grows with radius.
        static var cornerButtonInset: CGFloat {
            max(0, displayCornerRadius - 28) * cornerInsetScale
        }
    }

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
