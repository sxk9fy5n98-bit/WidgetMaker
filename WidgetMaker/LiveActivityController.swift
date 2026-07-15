import ActivityKit
import Foundation

@MainActor
enum LiveActivityController {
    static var isActivityInProgress: Bool {
        !Activity<WidgetUtilityAttributes>.activities.isEmpty
    }

    @discardableResult
    static func start(from configuration: SharedWidgetConfiguration) throws -> Activity<WidgetUtilityAttributes> {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notEnabled
        }

        // End any existing utility activities so we always show the latest config.
        for activity in Activity<WidgetUtilityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = WidgetUtilityAttributes(title: configuration.title)
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
            status: configuration.subtitle.isEmpty ? "Active" : configuration.subtitle,
            detail: "Updated \(formattedNow())",
            progress: 0.65,
            emoji: configuration.emoji.isEmpty ? "🐛" : configuration.emoji
        )
    }

    private static func formattedNow() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

enum LiveActivityError: LocalizedError {
    case notEnabled

    var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "Live Activities are disabled. Enable them in Settings."
        }
    }
}
