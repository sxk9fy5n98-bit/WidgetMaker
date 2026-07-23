import Foundation

enum SharedDataStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.suiteName)
    }

    @discardableResult
    static func save(_ configuration: SharedWidgetConfiguration) -> Bool {
        var sanitized = configuration
        sanitized.sanitize()

        guard
            let defaults,
            let data = try? JSONEncoder().encode(sanitized)
        else {
            return false
        }

        defaults.set(data, forKey: AppGroupConstants.widgetConfigurationKey)
        return true
    }

    static func load() -> SharedWidgetConfiguration? {
        guard
            let defaults,
            let data = defaults.data(forKey: AppGroupConstants.widgetConfigurationKey)
        else {
            return nil
        }

        guard var configuration = try? JSONDecoder().decode(SharedWidgetConfiguration.self, from: data) else {
            return nil
        }

        configuration.sanitize()
        return configuration
    }
}
