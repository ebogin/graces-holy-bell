import SwiftUI

/// Sticky-note glyph for prayer rows with an intention attached.
///
/// Simplified from "Note" by Omar Safaa (Noun Project #2893934): just the
/// note outline with a folded bottom-right corner — the inner text lines are
/// dropped so the shape stays legible at log-row size.
struct NoteGlyphShape: Shape {

    func path(in rect: CGRect) -> Path {
        // Design space is 24x24 (the source icon's grid); scale to rect.
        let s = min(rect.width, rect.height) / 24
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }

        var path = Path()

        // Note outline with the bottom-right corner cut for the fold.
        path.move(to: pt(4, 3))
        path.addLine(to: pt(20, 3))
        path.addLine(to: pt(20, 14))
        path.addLine(to: pt(13, 21))
        path.addLine(to: pt(4, 21))
        path.closeSubpath()

        // Folded-corner crease.
        path.move(to: pt(13, 21))
        path.addLine(to: pt(13, 14))
        path.addLine(to: pt(20, 14))

        return path
    }
}

/// Ready-to-place icon view: stroked NoteGlyphShape at a given point size.
/// Sized a touch larger than the 9pt row text and center-aligned with it.
struct NoteGlyphIcon: View {

    var size: CGFloat = 12
    var color: Color = .lcdMid

    var body: some View {
        NoteGlyphShape()
            .stroke(color, style: StrokeStyle(
                lineWidth: size * 2.6 / 24,
                lineCap: .round,
                lineJoin: .round
            ))
            .frame(width: size, height: size)
    }
}
