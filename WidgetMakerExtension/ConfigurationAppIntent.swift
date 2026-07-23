import AppIntents
import WidgetKit

struct WidgetDesignEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Design")
    static var defaultQuery = WidgetDesignQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct WidgetDesignQuery: EntityQuery {
    func entities(for identifiers: [WidgetDesignEntity.ID]) async throws -> [WidgetDesignEntity] {
        let portfolio = SharedDataStore.loadPortfolio()
        return identifiers.compactMap { id in
            guard let design = portfolio.designs.first(where: { $0.id == id }) else { return nil }
            return WidgetDesignEntity(id: design.id, name: design.displayName)
        }
    }

    func suggestedEntities() async throws -> [WidgetDesignEntity] {
        SharedDataStore.loadPortfolio().designs.map {
            WidgetDesignEntity(id: $0.id, name: $0.displayName)
        }
    }

    func defaultResult() async -> WidgetDesignEntity? {
        let design = SharedDataStore.loadPortfolio().selectedDesign
        return WidgetDesignEntity(id: design.id, name: design.displayName)
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Buggy Widget"
    static var description = IntentDescription("Shows one of your saved designs on the Home Screen.")

    @Parameter(title: "Design")
    var design: WidgetDesignEntity?

    init() {}

    init(design: WidgetDesignEntity?) {
        self.design = design
    }
}
