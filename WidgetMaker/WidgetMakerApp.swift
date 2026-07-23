//
//  WidgetMakerApp.swift
//  WidgetMaker
//

import SwiftUI

@main
struct WidgetMakerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color(red: 0.369, green: 0.361, blue: 0.898))
                .onOpenURL { url in
                    guard DeepLink.handles(url) else { return }
                    NotificationCenter.default.post(name: DeepLink.openEditorNotification, object: url)
                }
        }
    }
}
