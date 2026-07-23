import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if let converted = uiColor.cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            intent: .defaultIntent,
            options: nil
        ) {
            let srgb = UIColor(cgColor: converted)
            if srgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
                return hexString(red: red, green: green, blue: blue)
            }
        }

        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return hexString(red: red, green: green, blue: blue)
        }

        // Fallback for grayscale / non-RGB colors.
        var white: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &alpha) {
            return hexString(red: white, green: white, blue: white)
        }

        return "#000000"
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return "#000000" }
        return hexString(
            red: rgb.redComponent,
            green: rgb.greenComponent,
            blue: rgb.blueComponent
        )
        #else
        return "#000000"
        #endif
    }

    /// Returns the color with its brightness shifted by `delta` (-1...1).
    /// Used to build subtle gradients from a single stored hex color.
    func adjustedBrightness(_ delta: CGFloat) -> Color {
        #if canImport(UIKit)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return Color(
            hue: hue,
            saturation: saturation,
            brightness: min(max(brightness + delta, 0), 1),
            opacity: alpha
        )
        #else
        return self
        #endif
    }

    private func hexString(red: CGFloat, green: CGFloat, blue: CGFloat) -> String {
        let r = Int((min(max(red, 0), 1) * 255).rounded())
        let g = Int((min(max(green, 0), 1) * 255).rounded())
        let b = Int((min(max(blue, 0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
