import Foundation

/// Central place for shared localized copy used outside SwiftUI `Text("…")` lookups.
enum L10n {
    static var defaultWidgetTitle: String {
        String(localized: "My Widget", comment: "Default widget title before the user customizes it")
    }

    static var defaultWidgetSubtitle: String {
        String(localized: "Created with Buggy Widget", comment: "Default widget subtitle")
    }

    static var liveActivityActiveStatus: String {
        String(localized: "Active", comment: "Fallback Live Activity status when subtitle is empty")
    }

    static var liveActivitiesDisabled: String {
        String(
            localized: "Live Activities are turned off. Enable them in Settings → Buggy Widget → Live Activities.",
            comment: "Error when Live Activities are disabled in system settings"
        )
    }

    static var sharedStorageUnavailable: String {
        String(
            localized: "Shared storage is unavailable. Make sure App Groups are enabled for this app.",
            comment: "Error when App Group UserDefaults is unavailable"
        )
    }

    static var sharedStorageUnavailableShort: String {
        String(
            localized: "Shared storage is unavailable. Check App Group settings.",
            comment: "Short error when App Group container is unavailable"
        )
    }

    static func titleSubtitleLimits(titleLimit: Int, subtitleLimit: Int) -> String {
        String(
            localized: "Title up to \(titleLimit) characters. Subtitle up to \(subtitleLimit).",
            comment: "Footer under title/subtitle fields"
        )
    }

    static func accessibilityPercent(_ value: Double) -> String {
        let percent = LocaleFormatting.percent(value)
        return String(localized: "\(percent) progress", comment: "VoiceOver label for progress; includes localized percent")
    }

    static func accessibilityStep(number: Int, text: String) -> String {
        String(localized: "Step \(number). \(text)", comment: "VoiceOver label for a numbered help step")
    }
}
