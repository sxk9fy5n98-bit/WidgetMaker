//
//  ConfigurationAppIntent.swift
//  WidgetMakerExtension
//
//  Created by Jose Ignacio Montivero on 12/7/2026.
//

import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "Configure your widget." }

    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
