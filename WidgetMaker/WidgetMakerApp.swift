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
                .tint(Color(red: 0.22, green: 0.62, blue: 0.30))
                .onOpenURL { _ in
                    // Deep links from Live Activity open the editor (already root).
                }
        }
    }
}
