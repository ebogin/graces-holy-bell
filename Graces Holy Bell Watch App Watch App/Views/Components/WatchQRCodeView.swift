import SwiftUI

/// Draws a QR code as crisp pixel modules with a SwiftUI `Canvas`.
///
/// watchOS has no CoreImage, so the module matrix is produced by the vendored
/// pure-Swift encoder (`Shared/QRCodeKit`) and rendered here. Callers pass a
/// PRECOMPUTED matrix so re-renders (the header timer ticks every second) never
/// re-encode the code.
struct WatchQRCodeView: View {

    /// Row-major module matrix; `true` = a dark module.
    let modules: [[Bool]]
    var dark: Color = .lcdDark
    var light: Color = .lcdBackground
    /// Quiet zone (light margin) in modules on each side — required for scanning.
    var quietZone: Int = 2

    var body: some View {
        Canvas { ctx, size in
            // Fill the whole canvas with the light colour (also the quiet zone).
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(light)
            )

            let count = modules.count
            guard count > 0 else { return }

            let side = min(size.width, size.height)
            let total = count + quietZone * 2
            let module = side / CGFloat(total)

            // Centre the code within the canvas, then inset by the quiet zone.
            let originX = (size.width  - module * CGFloat(total)) / 2 + module * CGFloat(quietZone)
            let originY = (size.height - module * CGFloat(total)) / 2 + module * CGFloat(quietZone)

            // Slight overdraw (ceil) avoids hairline seams between modules.
            let cell = ceil(module)
            for (y, row) in modules.enumerated() {
                for (x, on) in row.enumerated() where on {
                    let rect = CGRect(
                        x: originX + CGFloat(x) * module,
                        y: originY + CGFloat(y) * module,
                        width: cell,
                        height: cell
                    )
                    ctx.fill(Path(rect), with: .color(dark))
                }
            }
        }
    }
}

extension WatchQRCodeView {

    /// Encodes `text` to a row-major module matrix (`true` = dark), or nil on
    /// failure. Uses medium error correction to match the iPhone's QR ("M").
    static func matrix(for text: String) -> [[Bool]]? {
        guard let qr = try? QRCode.encode(text: text, ecl: .medium) else { return nil }
        let n = qr.size
        return (0..<n).map { y in (0..<n).map { x in qr.getModule(x: x, y: y) } }
    }
}
