import SwiftUI

/// The lightweight "share / export" icon from Figma node 296:524 — a rounded
/// tray with an arrow leaving the top-right corner — as a vector `Shape`.
///
/// Built from the design's two filled paths in their native 35×35 viewBox and
/// scaled to fit, so it stays crisp at any size and tints with a plain fill.
/// Shared between the iPhone and Watch apps so both "Share with a Friend"
/// entry points use the identical glyph.
struct ShareIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 35
        // Centre the 35×35 glyph within the (square) rect.
        let dx = rect.minX + (rect.width - 35 * s) / 2
        let dy = rect.minY + (rect.height - 35 * s) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: dx + x * s, y: dy + y * s)
        }

        var path = Path()

        // Arrow (Vector)
        path.move(to: p(33.425, 0))
        path.addLine(to: p(24.7014, 0))
        path.addCurve(to: p(23.1264, 1.575), control1: p(23.8315, 0), control2: p(23.1264, 0.705163))
        path.addCurve(to: p(24.7014, 3.15), control1: p(23.1264, 2.44484), control2: p(23.8315, 3.15))
        path.addLine(to: p(29.6476, 3.15))
        path.addLine(to: p(13.8086, 19.1404))
        path.addCurve(to: p(13.8192, 21.3677), control1: p(13.1964, 19.7584), control2: p(13.2011, 20.7555))
        path.addCurve(to: p(14.9275, 21.8237), control1: p(14.1263, 21.6719), control2: p(14.5269, 21.8237))
        path.addCurve(to: p(16.0466, 21.3571), control1: p(15.3331, 21.8237), control2: p(15.7386, 21.6681))
        path.addLine(to: p(31.85, 5.4026))
        path.addLine(to: p(31.85, 10.2986))
        path.addCurve(to: p(33.425, 11.8736), control1: p(31.85, 11.1684), control2: p(32.5552, 11.8736))
        path.addCurve(to: p(35, 10.2986), control1: p(34.2949, 11.8736), control2: p(35, 11.1684))
        path.addLine(to: p(35, 1.575))
        path.addCurve(to: p(33.425, 0), control1: p(35, 0.705163), control2: p(34.2949, 0))
        path.closeSubpath()

        // Tray (Vector_2)
        path.move(to: p(29.062, 18.7682))
        path.addCurve(to: p(27.487, 20.3432), control1: p(28.1921, 18.7682), control2: p(27.487, 19.4733))
        path.addLine(to: p(27.487, 29.925))
        path.addCurve(to: p(25.562, 31.85), control1: p(27.487, 30.9865), control2: p(26.6234, 31.85))
        path.addLine(to: p(5.075, 31.85))
        path.addCurve(to: p(3.15, 29.925), control1: p(4.01354, 31.85), control2: p(3.15, 30.9865))
        path.addLine(to: p(3.15, 9.43804))
        path.addCurve(to: p(5.075, 7.51304), control1: p(3.15, 8.37658), control2: p(4.01354, 7.51304))
        path.addLine(to: p(14.6569, 7.51304))
        path.addCurve(to: p(16.2319, 5.93804), control1: p(15.5267, 7.51304), control2: p(16.2319, 6.80787))
        path.addCurve(to: p(14.6569, 4.36304), control1: p(16.2319, 5.0682), control2: p(15.5267, 4.36304))
        path.addLine(to: p(5.075, 4.36304))
        path.addCurve(to: p(0, 9.43804), control1: p(2.27666, 4.36304), control2: p(0, 6.6397))
        path.addLine(to: p(0, 29.925))
        path.addCurve(to: p(5.075, 35), control1: p(0, 32.7234), control2: p(2.27666, 35))
        path.addLine(to: p(25.562, 35))
        path.addCurve(to: p(30.637, 29.925), control1: p(28.3603, 35), control2: p(30.637, 32.7234))
        path.addLine(to: p(30.637, 20.3432))
        path.addCurve(to: p(29.062, 18.7682), control1: p(30.637, 19.4733), control2: p(29.9318, 18.7682))
        path.closeSubpath()

        return path
    }
}
