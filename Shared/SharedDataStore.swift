import Foundation

enum SharedDataStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.suiteName)
    }

    static func save(_ configuration: SharedWidgetConfiguration) {
        guard
            let defaults,
            let data = try? JSONEncoder().encode(configuration)
        else {
            return
        }

        defaults.set(data, forKey: AppGroupConstants.widgetConfigurationKey)
    }

    static func load() -> SharedWidgetConfiguration? {
        guard
            let defaults,
            let data = defaults.data(forKey: AppGroupConstants.widgetConfigurationKey)
        else {
            return nil
        }

        return try? JSONDecoder().decode(SharedWidgetConfiguration.self, from: data)
    }
}
