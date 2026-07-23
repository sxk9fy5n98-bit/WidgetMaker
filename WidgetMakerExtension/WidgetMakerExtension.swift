//
//  WidgetMakerExtension.swift
//  WidgetMakerExtension
//

import WidgetKit
import SwiftUI
import UIKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            widgetConfiguration: .default,
            backgroundImage: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        // Config reloads via WidgetCenter after Save. Time text auto-updates via Text date style.
        let timeline = Timeline(entries: [makeEntry()], policy: .never)
        completion(timeline)
    }

    private func makeEntry() -> SimpleEntry {
        let widgetConfiguration = SharedDataStore.load() ?? .default
        return SimpleEntry(
            date: Date(),
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
            showsProgress: true,
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
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetMakerExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Buggy Widget")
        .description("Your custom title, colors, font, progress, and background on the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    WidgetMakerExtension()
} timeline: {
    SimpleEntry(
        date: .now,
        widgetConfiguration: .default,
        backgroundImage: nil
    )
}
