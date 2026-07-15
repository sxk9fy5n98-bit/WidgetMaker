//
//  WidgetMakerExtension.swift
//  WidgetMakerExtension
//
//  Created by Jose Ignacio Montivero on 12/7/2026.
//

import WidgetKit
import SwiftUI
import UIKit

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            widgetConfiguration: .default,
            backgroundImage: nil
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = makeEntry(configuration: configuration)
        return Timeline(entries: [entry], policy: .atEnd)
    }

    private func makeEntry(configuration: ConfigurationAppIntent) -> SimpleEntry {
        let widgetConfiguration = SharedDataStore.load() ?? .default
        let backgroundImage = loadBackgroundImage(from: widgetConfiguration)

        return SimpleEntry(
            date: Date(),
            configuration: configuration,
            widgetConfiguration: widgetConfiguration,
            backgroundImage: backgroundImage
        )
    }

    private func loadBackgroundImage(from configuration: SharedWidgetConfiguration) -> UIImage? {
        guard
            let fileName = configuration.backgroundImageFileName,
            let data = SharedImageStore.loadImageData(fileName: fileName)
        else {
            return nil
        }

        return UIImage(data: data)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let widgetConfiguration: SharedWidgetConfiguration
    let backgroundImage: UIImage?
}

struct WidgetMakerExtensionEntryView: View {
    var entry: Provider.Entry

    private var config: SharedWidgetConfiguration {
        entry.widgetConfiguration
    }

    private var fontOption: WidgetFontOption {
        WidgetFontOption.resolve(config.fontName)
    }

    private var backgroundColor: Color {
        Color(hex: config.backgroundColorHex) ?? Color(hex: SharedWidgetConfiguration.default.backgroundColorHex) ?? .green
    }

    private var textColor: Color {
        Color(hex: config.textColorHex) ?? .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(config.emoji)
                .font(.system(size: 34))

            Text(config.title)
                .font(fontOption.font(size: 17, weight: .semibold))
                .foregroundStyle(textColor)
                .lineLimit(2)

            Text(config.subtitle)
                .font(fontOption.font(size: 13))
                .foregroundStyle(textColor.opacity(0.85))
                .lineLimit(2)

            Spacer(minLength: 0)

            Text(entry.date, style: .time)
                .font(fontOption.font(size: 11, weight: .medium))
                .foregroundStyle(textColor.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    @ViewBuilder
    private var widgetBackground: some View {
        if let backgroundImage = entry.backgroundImage {
            ZStack {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()

                backgroundColor.opacity(0.35)
            }
        } else {
            backgroundColor
        }
    }
}

struct WidgetMakerExtension: Widget {
    let kind: String = "WidgetMakerExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WidgetMakerExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Buggy Widget")
        .description("Shows your customized title, colors, font, and image.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    WidgetMakerExtension()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: ConfigurationAppIntent(),
        widgetConfiguration: .default,
        backgroundImage: nil
    )
}
