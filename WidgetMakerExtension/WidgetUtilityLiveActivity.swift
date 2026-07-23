//
//  WidgetUtilityLiveActivity.swift
//  WidgetMakerExtension
//

import ActivityKit
import SwiftUI
import WidgetKit

struct WidgetUtilityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WidgetUtilityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.emoji)
                        .font(.title2)
                        .accessibilityLabel("Status emoji")
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .accessibilityLabel("\(Int(context.state.progress * 100)) percent")
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.status)
                            .font(.subheadline)
                            .lineLimit(1)

                        ProgressView(value: context.state.progress)
                            .tint(Color(hex: SharedWidgetConfiguration.default.backgroundColorHex) ?? .green)

                        Text(context.state.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Text(context.state.emoji)
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "buggywidget://editor"))
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WidgetUtilityAttributes>) -> some View {
        HStack(spacing: 12) {
            Text(context.state.emoji)
                .font(.largeTitle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(context.state.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: context.state.progress)
                    .tint(Color(hex: SharedWidgetConfiguration.default.backgroundColorHex) ?? .green)

                Text(context.state.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("\(Int(context.state.progress * 100))%")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .accessibilityLabel("\(Int(context.state.progress * 100)) percent")
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
        .widgetURL(URL(string: "buggywidget://editor"))
    }
}

#Preview("Lock Screen", as: .content, using: WidgetUtilityAttributes(title: "My Widget")) {
    WidgetUtilityLiveActivity()
} contentStates: {
    WidgetUtilityAttributes.ContentState(
        status: "Created with Buggy Widget",
        detail: "Updated 8:30 PM",
        progress: 0.65,
        emoji: "🐛"
    )
}
