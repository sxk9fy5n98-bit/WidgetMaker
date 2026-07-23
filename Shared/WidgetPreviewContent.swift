import SwiftUI
import UIKit

/// Shared visual used by the in-app preview and the Home Screen widget.
struct WidgetPreviewContent: View {
    let configuration: SharedWidgetConfiguration
    var backgroundImage: UIImage?
    var showsTimestamp: Bool = true
    var showsProgress: Bool = true
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

    var body: some View {
        let framed = content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(isCompact ? 14 : 16)
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
            Text(configuration.displayEmoji)
                .font(.system(size: isCompact ? 34 : 42))
                .accessibilityHidden(true)

            Text(configuration.displayTitle)
                .font(fontOption.font(size: isCompact ? 17 : 20, weight: .semibold))
                .foregroundStyle(textColor)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if !configuration.displaySubtitle.isEmpty {
                Text(configuration.displaySubtitle)
                    .font(fontOption.font(size: isCompact ? 13 : 15))
                    .foregroundStyle(textColor.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            if showsProgress {
                ProgressView(value: configuration.clampedProgress)
                    .tint(textColor.opacity(0.9))
                    .accessibilityLabel(Text("Progress"))
                    .accessibilityValue(L10n.accessibilityPercent(configuration.clampedProgress))
            }

            if showsTimestamp {
                // WidgetKit auto-updates Text date styles without a timeline reload.
                Text(Date(), style: .time)
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
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()

                backgroundColor.opacity(0.35)
            }
        } else {
            backgroundColor
        }
    }

    private var accessibilitySummary: String {
        var parts = [configuration.displayTitle]
        if !configuration.displaySubtitle.isEmpty {
            parts.append(configuration.displaySubtitle)
        }
        if showsProgress {
            parts.append(L10n.accessibilityPercent(configuration.clampedProgress))
        }
        return parts.joined(separator: ", ")
    }
}
