import ActivityKit
import Foundation

struct WidgetUtilityAttributes: ActivityAttributes {
    /// Dynamic payload pushed to Lock Screen / Dynamic Island (fully updatable).
    public struct ContentState: Codable, Hashable {
        var title: String
        var status: String
        var detail: String
        var progress: Double
        var emoji: String
        var accentColorHex: String
        var textColorHex: String
        var fontName: String
        var backgroundImageFileName: String?
        var showsEmoji: Bool
        var showsTitle: Bool
        var showsSubtitle: Bool
        var showsProgress: Bool
        var showsDetail: Bool
    }

    /// Stable identity for this Live Activity kind.
    var widgetID: String
}
