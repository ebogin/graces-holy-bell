import SwiftUI

/// Renders a 13×13 pixel grid as a round button.
/// D = lcdDark fill, L = lcdThumbText icon, . = transparent
struct PixelGridButton: View {

    enum Cell { case dark, light, clear }

    let grid: [[Cell]]
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Canvas { ctx, _ in
                let p = size / 13
                for (y, row) in grid.enumerated() {
                    for (x, cell) in row.enumerated() where cell != .clear {
                        let rect = CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: p, height: p)
                        ctx.fill(Path(rect), with: .color(cell == .dark ? Color.lcdDark : Color.lcdThumbText))
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}

struct BackButton: View {
    let action: () -> Void
    var size: CGFloat = 28

    private static let grid: [[PixelGridButton.Cell]] = [
        [.clear,.clear,.clear,.clear,.dark,.dark,.dark,.dark,.dark,.clear,.clear,.clear,.clear],
        [.clear,.clear,.clear,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.clear,.clear,.clear],
        [.clear,.clear,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.clear,.clear],
        [.clear,.dark,.dark,.dark,.dark,.dark,.dark,.light,.dark,.dark,.dark,.dark,.clear],
        [.dark,.dark,.dark,.dark,.dark,.dark,.light,.dark,.dark,.dark,.dark,.dark,.dark],
        [.dark,.dark,.dark,.dark,.dark,.light,.dark,.dark,.dark,.dark,.dark,.dark,.dark],
        [.dark,.dark,.dark,.dark,.light,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark],
        [.dark,.dark,.dark,.dark,.dark,.light,.dark,.dark,.dark,.dark,.dark,.dark,.dark],
        [.dark,.dark,.dark,.dark,.dark,.dark,.light,.dark,.dark,.dark,.dark,.dark,.dark],
        [.clear,.dark,.dark,.dark,.dark,.dark,.dark,.light,.dark,.dark,.dark,.dark,.clear],
        [.clear,.clear,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.clear,.clear],
        [.clear,.clear,.clear,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.clear,.clear,.clear],
        [.clear,.clear,.clear,.clear,.dark,.dark,.dark,.dark,.dark,.clear,.clear,.clear,.clear],
    ]

    var body: some View {
        PixelGridButton(grid: Self.grid, size: size, action: action)
    }
}

struct ClearButton: View {
    let action: () -> Void
    var size: CGFloat = 28

    private static let grid: [[PixelGridButton.Cell]] = [
        [.clear,.clear,.clear,.clear,.dark,.dark,.dark,.dark,.dark,.clear,.clear,.clear,.clear],
        [.clear,.clear,.clear,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.clear,.clear,.clear],
        [.clear,.clear,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.clear,.clear],
        [.clear,.dark,.dark,.light,.light,.dark,.dark,.dark,.light,.light,.dark,.dark,.clear],
        [.dark,.dark,.dark,.dark,.light,.light,.dark,.light,.light,.dark,.dark,.dark,.dark],
        [.dark,.dark,.dark,.dark,.dark,.light,.light,.light,.dark,.dark,.dark,.dark,.dark],
        [.dark,.dark,.dark,.dark,.dark,.dark,.light,.dark,.dark,.dark,.dark,.dark,.dark],
        [.dark,.dark,.dark,.dark,.dark,.light,.light,.light,.dark,.dark,.dark,.dark,.dark],
        [.dark,.dark,.dark,.dark,.light,.light,.dark,.light,.light,.dark,.dark,.dark,.dark],
        [.clear,.dark,.dark,.light,.light,.dark,.dark,.dark,.light,.light,.dark,.dark,.clear],
        [.clear,.clear,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.clear,.clear],
        [.clear,.clear,.clear,.dark,.dark,.dark,.dark,.dark,.dark,.dark,.clear,.clear,.clear],
        [.clear,.clear,.clear,.clear,.dark,.dark,.dark,.dark,.dark,.clear,.clear,.clear,.clear],
    ]

    var body: some View {
        PixelGridButton(grid: Self.grid, size: size, action: action)
    }
}
