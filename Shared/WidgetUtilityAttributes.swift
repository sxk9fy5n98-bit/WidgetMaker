import ActivityKit
import Foundation

struct WidgetUtilityAttributes: ActivityAttributes {
    /// Dynamic payload pushed to Lock Screen / Dynamic Island.
    public struct ContentState: Codable, Hashable {
        var status: String
        var detail: String
        var progress: Double
        var emoji: String
    }

    /// Fixed for the lifetime of the Live Activity.
    var title: String
}
