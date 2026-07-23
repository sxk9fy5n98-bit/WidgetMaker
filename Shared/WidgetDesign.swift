import Foundation

/// One saved look in the user's design portfolio.
struct WidgetDesign: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var configuration: SharedWidgetConfiguration

    init(
        id: String = UUID().uuidString,
        name: String,
        configuration: SharedWidgetConfiguration = .default
    ) {
        self.id = id
        self.name = name
        self.configuration = configuration
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.untitledDesign : trimmed
    }

    mutating func sanitize() {
        name = String(name.prefix(Self.nameLimit))
        configuration.sanitize()
    }

    static let nameLimit = 40
}

/// Collection of designs shared with Home Screen widgets via App Group.
struct WidgetPortfolio: Codable, Equatable {
    var designs: [WidgetDesign]
    /// Design currently open in the editor (and used for Live Activity).
    var selectedDesignID: String

    static var `default`: WidgetPortfolio {
        let design = WidgetDesign(
            name: L10n.defaultDesignName,
            configuration: .default
        )
        return WidgetPortfolio(designs: [design], selectedDesignID: design.id)
    }

    static let maxDesigns = 20

    var selectedDesign: WidgetDesign {
        designs.first(where: { $0.id == selectedDesignID }) ?? designs[0]
    }

    mutating func select(_ id: String) {
        guard designs.contains(where: { $0.id == id }) else { return }
        selectedDesignID = id
    }

    mutating func updateSelected(_ configuration: SharedWidgetConfiguration, name: String? = nil) {
        guard let index = designs.firstIndex(where: { $0.id == selectedDesignID }) else { return }
        designs[index].configuration = configuration
        if let name {
            designs[index].name = name
        }
        designs[index].sanitize()
    }

    @discardableResult
    mutating func addDesign(copyingSelected: Bool = false) -> WidgetDesign? {
        guard designs.count < Self.maxDesigns else { return nil }
        let source = selectedDesign
        let design = WidgetDesign(
            name: L10n.newDesignName(index: designs.count + 1),
            configuration: copyingSelected ? source.configuration : .default
        )
        designs.append(design)
        selectedDesignID = design.id
        return design
    }

    @discardableResult
    mutating func duplicateSelected() -> WidgetDesign? {
        guard designs.count < Self.maxDesigns else { return nil }
        let source = selectedDesign
        let design = WidgetDesign(
            name: L10n.duplicatedDesignName(source.displayName),
            configuration: source.configuration
        )
        designs.append(design)
        selectedDesignID = design.id
        return design
    }

    @discardableResult
    mutating func deleteSelected() -> Bool {
        guard designs.count > 1,
              let index = designs.firstIndex(where: { $0.id == selectedDesignID })
        else {
            return false
        }
        designs.remove(at: index)
        selectedDesignID = designs[min(index, designs.count - 1)].id
        return true
    }

    func design(id: String?) -> WidgetDesign? {
        guard let id else { return designs.first }
        return designs.first(where: { $0.id == id }) ?? designs.first
    }

    mutating func sanitize() {
        if designs.isEmpty {
            self = .default
            return
        }
        for index in designs.indices {
            designs[index].sanitize()
        }
        if !designs.contains(where: { $0.id == selectedDesignID }) {
            selectedDesignID = designs[0].id
        }
    }
}
