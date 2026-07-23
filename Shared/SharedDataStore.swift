import Foundation

enum SharedDataStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConstants.suiteName)
    }

    // MARK: - Portfolio

    @discardableResult
    static func savePortfolio(_ portfolio: WidgetPortfolio) -> Bool {
        var sanitized = portfolio
        sanitized.sanitize()

        guard
            let defaults,
            let data = try? JSONEncoder().encode(sanitized)
        else {
            return false
        }

        defaults.set(data, forKey: AppGroupConstants.widgetPortfolioKey)
        // Keep legacy key in sync with the selected design for older readers / safety.
        _ = saveLegacyConfiguration(sanitized.selectedDesign.configuration)
        return true
    }

    static func loadPortfolio() -> WidgetPortfolio {
        if let portfolio = loadPortfolioRaw() {
            var value = portfolio
            value.sanitize()
            return value
        }

        if let legacy = loadLegacyConfiguration() {
            let design = WidgetDesign(name: L10n.defaultDesignName, configuration: legacy)
            let portfolio = WidgetPortfolio(designs: [design], selectedDesignID: design.id)
            _ = savePortfolio(portfolio)
            return portfolio
        }

        let portfolio = WidgetPortfolio.default
        _ = savePortfolio(portfolio)
        return portfolio
    }

    static func design(id: String?) -> WidgetDesign {
        loadPortfolio().design(id: id) ?? WidgetPortfolio.default.designs[0]
    }

    // MARK: - Legacy single configuration (migration + Live Activity convenience)

    @discardableResult
    static func save(_ configuration: SharedWidgetConfiguration) -> Bool {
        var portfolio = loadPortfolio()
        portfolio.updateSelected(configuration)
        return savePortfolio(portfolio)
    }

    static func load() -> SharedWidgetConfiguration? {
        loadPortfolio().selectedDesign.configuration
    }

    // MARK: - Private

    private static func loadPortfolioRaw() -> WidgetPortfolio? {
        guard
            let defaults,
            let data = defaults.data(forKey: AppGroupConstants.widgetPortfolioKey),
            let portfolio = try? JSONDecoder().decode(WidgetPortfolio.self, from: data)
        else {
            return nil
        }
        return portfolio
    }

    private static func loadLegacyConfiguration() -> SharedWidgetConfiguration? {
        guard
            let defaults,
            let data = defaults.data(forKey: AppGroupConstants.widgetConfigurationKey),
            var configuration = try? JSONDecoder().decode(SharedWidgetConfiguration.self, from: data)
        else {
            return nil
        }
        configuration.sanitize()
        return configuration
    }

    @discardableResult
    private static func saveLegacyConfiguration(_ configuration: SharedWidgetConfiguration) -> Bool {
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
}
