import Foundation

struct SharedWidgetConfiguration: Codable, Equatable {
    var title: String
    var subtitle: String
    var emoji: String
    var backgroundColorHex: String
    var textColorHex: String
    var fontName: String
    /// 0...1 progress shown on Live Activity / Dynamic Island.
    var progress: Double
    /// Filename only — image bytes live in the App Group container via FileManager.
    var backgroundImageFileName: String?

    /// Localized defaults for first launch (evaluated at access time).
    static var `default`: SharedWidgetConfiguration {
        SharedWidgetConfiguration(
            title: L10n.defaultWidgetTitle,
            subtitle: L10n.defaultWidgetSubtitle,
            emoji: "🐛",
            backgroundColorHex: "#AAFF8E",
            textColorHex: "#000000",
            fontName: WidgetFontOption.system.rawValue,
            progress: 0.65,
            backgroundImageFileName: nil
        )
    }

    static let titleLimit = 40
    static let subtitleLimit = 60
    static let emojiLimit = 8

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.default.title : trimmed
    }

    var displaySubtitle: String {
        subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayEmoji: String {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.default.emoji : trimmed
    }

    var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    mutating func sanitize() {
        title = String(title.prefix(Self.titleLimit))
        subtitle = String(subtitle.prefix(Self.subtitleLimit))
        emoji = String(emoji.prefix(Self.emojiLimit))
        progress = clampedProgress
    }

    enum CodingKeys: String, CodingKey {
        case title, subtitle, emoji, backgroundColorHex, textColorHex, fontName, progress, backgroundImageFileName
    }

    init(
        title: String,
        subtitle: String,
        emoji: String,
        backgroundColorHex: String,
        textColorHex: String,
        fontName: String,
        progress: Double,
        backgroundImageFileName: String?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.emoji = emoji
        self.backgroundColorHex = backgroundColorHex
        self.textColorHex = textColorHex
        self.fontName = fontName
        self.progress = progress
        self.backgroundImageFileName = backgroundImageFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        emoji = try container.decode(String.self, forKey: .emoji)
        backgroundColorHex = try container.decode(String.self, forKey: .backgroundColorHex)
        textColorHex = try container.decode(String.self, forKey: .textColorHex)
        fontName = try container.decode(String.self, forKey: .fontName)
        progress = try container.decodeIfPresent(Double.self, forKey: .progress) ?? Self.default.progress
        backgroundImageFileName = try container.decodeIfPresent(String.self, forKey: .backgroundImageFileName)
    }
}
