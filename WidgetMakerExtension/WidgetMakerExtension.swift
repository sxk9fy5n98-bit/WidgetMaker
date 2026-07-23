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
        // Config reloads via WidgetCenter after Save. Time text auto-updates via Text date style.
        Timeline(entries: [makeEntry(configuration: configuration)], policy: .never)
    }

    private func makeEntry(configuration: ConfigurationAppIntent) -> SimpleEntry {
        let design = SharedDataStore.design(id: configuration.design?.id)
        let widgetConfiguration = design.configuration
        return SimpleEntry(
            date: Date(),
            configuration: configuration,
            widgetConfiguration: widgetConfiguration,
            backgroundImage: loadBackgroundImage(from: widgetConfiguration)
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
