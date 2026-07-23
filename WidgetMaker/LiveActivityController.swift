import ActivityKit
import Foundation

@MainActor
enum LiveActivityController {
    static var isActivityInProgress: Bool {
        !Activity<WidgetUtilityAttributes>.activities.isEmpty
    }

    @discardableResult
    static func start(from configuration: SharedWidgetConfiguration) async throws -> Activity<WidgetUtilityAttributes> {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notEnabled
        }

        // End any existing utility activities so we always show the latest config.
        for activity in Activity<WidgetUtilityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let attributes = WidgetUtilityAttributes(widgetID: "buggy-widget")
        let state = contentState(from: configuration)

        return try Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
    }

    static func update(from configuration: SharedWidgetConfiguration) async {
        let state = contentState(from: configuration)
        let content = ActivityContent(state: state, staleDate: nil)

        for activity in Activity<WidgetUtilityAttributes>.activities {
            await activity.update(content)
        }
    }

    static func endAll() async {
        for activity in Activity<WidgetUtilityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func contentState(from configuration: SharedWidgetConfiguration) -> WidgetUtilityAttributes.ContentState {
        WidgetUtilityAttributes.ContentState(
            title: configuration.displayTitle,
            status: configuration.displaySubtitle.isEmpty ? L10n.liveActivityActiveStatus : configuration.displaySubtitle,
            detail: LocaleFormatting.updatedAt(),
            progress: configuration.clampedProgress,
            emoji: configuration.displayEmoji,
            accentColorHex: configuration.backgroundColorHex,
            textColorHex: configuration.textColorHex,
            fontName: configuration.fontName,
            backgroundImageFileName: configuration.backgroundImageFileName
        )
    }
}

enum LiveActivityError: LocalizedError {
    case notEnabled

    var errorDescription: String? {
        switch self {
        case .notEnabled:
            return L10n.liveActivitiesDisabled
        }
    }
}
