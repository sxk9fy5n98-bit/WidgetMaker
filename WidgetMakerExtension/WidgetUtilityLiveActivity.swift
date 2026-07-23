//
//  WidgetUtilityLiveActivity.swift
//  WidgetMakerExtension
//

import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

struct WidgetUtilityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WidgetUtilityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            let accent = accentColor(for: context.state)
            let fontOption = WidgetFontOption.resolve(context.state.fontName)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.emoji)
                        .font(.title2)
                        .accessibilityLabel(Text("Status emoji"))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(LocaleFormatting.percent(context.state.progress))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                        .accessibilityLabel(L10n.accessibilityPercent(context.state.progress))
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(fontOption.font(size: 17, weight: .semibold))
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.status)
                            .font(fontOption.font(size: 14))
                            .lineLimit(1)

                        ProgressView(value: context.state.progress)
                            .tint(accent)

                        Text(context.state.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Text(context.state.emoji)
            } compactTrailing: {
                Text(LocaleFormatting.percent(context.state.progress))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "buggywidget://editor"))
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WidgetUtilityAttributes>) -> some View {
        let accent = accentColor(for: context.state)
        let textColor = Color(hex: context.state.textColorHex) ?? .white
        let fontOption = WidgetFontOption.resolve(context.state.fontName)
        let backgroundImage = loadBackgroundImage(fileName: context.state.backgroundImageFileName)

        HStack(spacing: 12) {
            Text(context.state.emoji)
                .font(.largeTitle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.title)
                    .font(fontOption.font(size: 17, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)

                Text(context.state.status)
                    .font(fontOption.font(size: 14))
                    .foregroundStyle(textColor.opacity(0.85))
                    .lineLimit(1)

                ProgressView(value: context.state.progress)
                    .tint(accent)

                Text(context.state.detail)
                    .font(.caption2)
                    .foregroundStyle(textColor.opacity(0.7))
            }

            Spacer(minLength: 0)

            Text(LocaleFormatting.percent(context.state.progress))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(textColor)
                .accessibilityLabel(L10n.accessibilityPercent(context.state.progress))
        }
        .padding()
        .background {
            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .overlay(accent.opacity(0.35))
            } else {
                accent.opacity(0.55)
            }
        }
        .activityBackgroundTint(accent.opacity(0.35))
        .activitySystemActionForegroundColor(textColor)
        .widgetURL(URL(string: "buggywidget://editor"))
    }

    private func accentColor(for state: WidgetUtilityAttributes.ContentState) -> Color {
        Color(hex: state.accentColorHex)
            ?? Color(hex: SharedWidgetConfiguration.default.backgroundColorHex)
            ?? .green
    }

    private func loadBackgroundImage(fileName: String?) -> UIImage? {
        guard
            let fileName,
            let data = SharedImageStore.loadImageData(fileName: fileName)
        else {
            return nil
        }
        return UIImage(data: data)
    }
}

#Preview("Lock Screen", as: .content, using: WidgetUtilityAttributes(widgetID: "buggy-widget")) {
    WidgetUtilityLiveActivity()
} contentStates: {
    WidgetUtilityAttributes.ContentState(
        title: L10n.defaultWidgetTitle,
        status: L10n.defaultWidgetSubtitle,
        detail: LocaleFormatting.updatedAt(),
        progress: 0.65,
        emoji: "🐛",
        accentColorHex: SharedWidgetConfiguration.default.backgroundColorHex,
        textColorHex: SharedWidgetConfiguration.default.textColorHex,
        fontName: WidgetFontOption.system.rawValue,
        backgroundImageFileName: nil
    )
}
