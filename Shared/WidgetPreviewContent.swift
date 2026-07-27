import SwiftUI
import UIKit
import WidgetKit

/// Shared visual used by the in-app preview and the Home Screen widget.
struct WidgetPreviewContent: View {
    let configuration: SharedWidgetConfiguration
    var backgroundImage: UIImage?
    /// Timestamp shown when "Show Time" is on. The widget passes its timeline
    /// entry date; the in-app preview defaults to now.
    var date: Date = Date()
    var isCompact: Bool = true
    /// When false, skip corner clipping so WidgetKit can apply system chrome.
    var clipsToWidgetShape: Bool = true

    private var fontOption: WidgetFontOption {
        WidgetFontOption.resolve(configuration.fontName)
    }

    private var backgroundColor: Color {
        Color(hex: configuration.backgroundColorHex)
            ?? Color(hex: SharedWidgetConfiguration.default.backgroundColorHex)
            ?? .green
    }

    private var textColor: Color {
        Color(hex: configuration.textColorHex) ?? .black
    }

    private var showsAnyForegroundContent: Bool {
        configuration.showsEmoji
            || configuration.showsTitle
            || (configuration.showsSubtitle && !configuration.displaySubtitle.isEmpty)
            || configuration.showsProgress
            || configuration.showsTimestamp
    }

    var body: some View {
        let framed = content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showsAnyForegroundContent ? .topLeading : .center)
            .padding(showsAnyForegroundContent ? (isCompact ? 14 : 16) : 0)
            .background { widgetBackground }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)

        if clipsToWidgetShape {
            framed
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            framed
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            if configuration.showsEmoji {
                Text(configuration.displayEmoji)
                    .font(.system(size: isCompact ? 34 : 42))
                    .accessibilityHidden(true)
            }

            if configuration.showsTitle {
                Text(configuration.displayTitle)
                    .font(fontOption.font(size: isCompact ? 17 : 20, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            if configuration.showsSubtitle, !configuration.displaySubtitle.isEmpty {
                Text(configuration.displaySubtitle)
                    .font(fontOption.font(size: isCompact ? 13 : 15))
                    .foregroundStyle(textColor.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            if showsAnyForegroundContent {
                Spacer(minLength: 0)
            }

            if configuration.showsProgress {
                ProgressView(value: configuration.clampedProgress)
                    .tint(textColor.opacity(0.9))
                    .accessibilityLabel(Text("Progress"))
                    .accessibilityValue(L10n.accessibilityPercent(configuration.clampedProgress))
            }

            if configuration.showsTimestamp {
                // Static render of the entry date; the provider emits per-minute
                // entries so this stays current on the Home Screen.
                Text(date, style: .time)
                    .font(fontOption.font(size: 11, weight: .medium))
                    .foregroundStyle(textColor.opacity(0.7))
                    .accessibilityLabel(Text("Current time"))
            }
        }
    }

    @ViewBuilder
    private var widgetBackground: some View {
        if let backgroundImage {
            ZStack {
                backgroundImageView(backgroundImage)

                // Dim only when overlays need contrast; keep photo-only widgets clean.
                if showsAnyForegroundContent {
                    LinearGradient(
                        colors: [backgroundColor.opacity(0.15), backgroundColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        } else {
            // Subtle diagonal gradient derived from the single stored color.
            LinearGradient(
                colors: [
                    backgroundColor.adjustedBrightness(0.10),
                    backgroundColor.adjustedBrightness(-0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func backgroundImageView(_ uiImage: UIImage) -> some View {
        let image = Image(uiImage: uiImage).resizable()
        if #available(iOS 18.0, *) {
            // Keep the photo full color when the Home Screen uses tinted widgets;
            // the default treatment desaturates it into a flat accent block.
            image
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFill()
        } else {
            image.scaledToFill()
        }
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        if configuration.showsTitle {
            parts.append(configuration.displayTitle)
        }
        if configuration.showsSubtitle, !configuration.displaySubtitle.isEmpty {
            parts.append(configuration.displaySubtitle)
        }
        if configuration.showsProgress {
            parts.append(L10n.accessibilityPercent(configuration.clampedProgress))
        }
        if parts.isEmpty {
            parts.append(String(localized: "Widget background"))
        }
        return parts.joined(separator: ", ")
    }
}
