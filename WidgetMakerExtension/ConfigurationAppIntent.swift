//
//  ConfigurationAppIntent.swift
//  WidgetMakerExtension
//

import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Buggy Widget" }
    static var description: IntentDescription {
        "Shows the design you saved in the Buggy Widget app."
    }
}
