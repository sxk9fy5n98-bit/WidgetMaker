//
//  WidgetMakerExtension.swift
//  WidgetMakerExtension
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
        makeEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        // Config reloads via WidgetCenter after Save.
        let widgetConfiguration = SharedDataStore.design(id: configuration.design?.id).configuration
        // Load once and share across entries to keep the provider's memory flat.
        let backgroundImage = loadBackgroundImage(from: widgetConfiguration)

        func entry(at date: Date) -> SimpleEntry {
            SimpleEntry(
                date: date,
                configuration: configuration,
                widgetConfiguration: widgetConfiguration,
                backgroundImage: backgroundImage
            )
        }

        guard widgetConfiguration.showsTimestamp else {
            return Timeline(entries: [entry(at: Date())], policy: .never)
        }

        // Text(_, style: .time) is a static render, so emit one entry per minute
        // to keep the clock current. `.atEnd` requests the next hour of entries.
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .minute, for: Date())?.start ?? Date()
        let entries = (0..<60).compactMap { minuteOffset -> SimpleEntry? in
            calendar.date(byAdding: .minute, value: minuteOffset, to: start).map(entry(at:))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makeEntry(date: Date, configuration: ConfigurationAppIntent) -> SimpleEntry {
        let design = SharedDataStore.design(id: configuration.design?.id)
        let widgetConfiguration = design.configuration
        return SimpleEntry(
            date: date,
            configuration: configuration,
            widgetConfiguration: widgetConfiguration,
            backgroundImage: loadBackgroundImage(from: widgetConfiguration)
        )
    }

    private func loadBackgroundImage(from configuration: SharedWidgetConfiguration) -> UIImage? {
        guard let fileName = configuration.backgroundImageFileName else { return nil }
        return SharedImageStore.loadImage(fileName: fileName)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let widgetConfiguration: SharedWidgetConfiguration
    let backgroundImage: UIImage?
}

struct WidgetMakerExtensionEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        WidgetPreviewContent(
            configuration: entry.widgetConfiguration,
            backgroundImage: entry.backgroundImage,
            date: entry.date,
            isCompact: family == .systemSmall,
            clipsToWidgetShape: false
        )
        .containerBackground(for: .widget) {
            Color.clear
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
        .description("Pick any design from your portfolio for the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
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
