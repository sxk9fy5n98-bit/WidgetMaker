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
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
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
                            .tint(.green)

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
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WidgetUtilityAttributes>) -> some View {
        HStack(spacing: 12) {
            Text(context.state.emoji)
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.headline)

                Text(context.state.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ProgressView(value: context.state.progress)
                    .tint(.green)

                Text(context.state.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text("\(Int(context.state.progress * 100))%")
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }
}

#Preview("Lock Screen", as: .content, using: WidgetUtilityAttributes(title: "My Widget")) {
    WidgetUtilityLiveActivity()
} contentStates: {
    WidgetUtilityAttributes.ContentState(
        status: "Created with WidgetMaker",
        detail: "Updated 8:30 PM",
        progress: 0.65,
        emoji: "🐛"
    )
}
