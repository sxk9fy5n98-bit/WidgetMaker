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
        makeEntry(configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = makeEntry(configuration: configuration)
        // Refresh periodically so the clock stays reasonably current.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
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
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        WidgetPreviewContent(
            configuration: entry.widgetConfiguration,
            backgroundImage: entry.backgroundImage,
            showsTimestamp: true,
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
        .description("Your custom title, colors, font, and background on the Home Screen.")
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
