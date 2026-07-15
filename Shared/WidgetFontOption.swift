import SwiftUI

enum WidgetFontOption: String, CaseIterable, Identifiable {
    case system = "System"
    case rounded = "Rounded"
    case serif = "Serif"
    case monospaced = "Monospaced"

    var id: String { rawValue }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: weight)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .monospaced:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }

    static func resolve(_ name: String) -> WidgetFontOption {
        WidgetFontOption(rawValue: name) ?? .system
    }
}
