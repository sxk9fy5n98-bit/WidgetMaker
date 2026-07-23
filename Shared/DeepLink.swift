import Foundation

enum DeepLink {
    static let editorURL = URL(string: "buggywidget://editor")!

    static let openEditorNotification = Notification.Name("BuggyWidgetOpenEditor")

    static func handles(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "buggywidget"
    }
}
