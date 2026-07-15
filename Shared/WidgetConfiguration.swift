import Foundation

struct SharedWidgetConfiguration: Codable, Equatable {
    var title: String
    var subtitle: String
    var emoji: String
    var backgroundColorHex: String
    var textColorHex: String
    var fontName: String
    /// Filename only — image bytes live in the App Group container via FileManager.
    var backgroundImageFileName: String?

    static let `default` = SharedWidgetConfiguration(
        title: "My Widget",
        subtitle: "Created with WidgetMaker",
        emoji: "🐛",
        backgroundColorHex: "#AAFF8E",
        textColorHex: "#000000",
        fontName: "System",
        backgroundImageFileName: nil
    )
}
