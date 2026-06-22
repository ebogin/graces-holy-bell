import SwiftUI
import CoreImage.CIFilterBuiltins

/// Generates QR codes on-device (no network, no third-party service) and tints
/// them to match the app's LCD-green theme.
enum QRCodeGenerator {

    private static let context = CIContext()

    /// Renders `string` as a QR code with `dark` modules on a `light` background.
    ///
    /// The image is scaled up with nearest-neighbour sampling so the modules stay
    /// crisp and square (use `.interpolation(.none)` when displaying).
    static func image(from string: String, dark: Color, light: Color) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        // Recolour: color0 = modules ("on"), color1 = background.
        let falseColor = CIFilter.falseColor()
        falseColor.inputImage = output
        falseColor.color0 = CIColor(color: UIColor(dark))
        falseColor.color1 = CIColor(color: UIColor(light))
        guard let recoloured = falseColor.outputImage else { return nil }

        let scale: CGFloat = 16
        let scaled = recoloured.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
