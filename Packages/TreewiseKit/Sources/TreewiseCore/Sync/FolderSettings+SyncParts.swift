import Foundation

/// A folder's settings as parts that merge on their own (ADR 0144): each property one part,
/// except that a module's template and the saved pattern it was picked from are one, as
/// they mean something only together, and each member of a set is a part of its own.
extension FolderSettings {
    private enum Part {
        static let enabledModules = "enabledModules"
        static let moduleOrder = "moduleOrder"
        static let module = "module/"
        static let newFolders = "newFolders"
        static let templateBarClosed = "templateBarClosed"
        static let offersNoMissingFolders = "offersNoMissingFolders"
        static let madeFrom = "madeFrom"
        static let alwaysSkipped = "alwaysSkipped/"
        static let missingFoldersClosed = "missingFoldersClosed/"
        static let namesKeptApart = "namesKeptApart/"
    }

    /// A module's template with the saved pattern it was picked from.
    private struct ModulePart: Codable, Equatable {
        var template: String?
        var link: SavedPatternLink?
    }

    /// The settings as parts.
    public var syncParts: [String: JSONValue] {
        var parts: [String: JSONValue] = [
            Part.enabledModules: .array(enabledModules.map(JSONValue.string)),
            Part.moduleOrder: .array(moduleOrder.map(JSONValue.string)),
            Part.templateBarClosed: .bool(templateBarClosed),
            Part.offersNoMissingFolders: .bool(offersNoMissingFolders),
            Part.madeFrom: .array(madeFrom.map(JSONValue.string)),
        ]
        parts[Part.newFolders] = try? JSONValue(encoding: newFolders)
        for module in Set(templates.keys).union(savedPatternLinks.keys) {
            parts[Part.module + module] = try? JSONValue(
                encoding: ModulePart(template: templates[module], link: savedPatternLinks[module]))
        }
        for name in alwaysSkipped { parts[Part.alwaysSkipped + name] = .bool(true) }
        for place in missingFoldersClosed {
            parts[Part.missingFoldersClosed + Self.member(place)] = .bool(true)
        }
        for names in namesKeptApart {
            parts[Part.namesKeptApart + Self.member(names)] = .bool(true)
        }
        return parts
    }

    /// The settings from their parts, leaving out parts this version does not know; nil
    /// without the modules' part, which every settings have.
    public init?(syncParts parts: [String: JSONValue]) {
        guard let enabled = parts[Part.enabledModules]?.decoded(as: [String].self) else {
            return nil
        }
        self.init(enabledModules: enabled, templates: [:])
        moduleOrder = parts[Part.moduleOrder]?.decoded(as: [String].self) ?? []
        newFolders = parts[Part.newFolders]?.decoded(as: NewFolders.self) ?? .automatic
        templateBarClosed = parts[Part.templateBarClosed] == .bool(true)
        offersNoMissingFolders = parts[Part.offersNoMissingFolders] == .bool(true)
        madeFrom = parts[Part.madeFrom]?.decoded(as: [String].self) ?? []
        for (part, value) in parts {
            if let module = part.after(Part.module), let unit = value.decoded(as: ModulePart.self) {
                templates[module] = unit.template
                savedPatternLinks[module] = unit.link
            } else if value == .bool(true) {
                takeMember(part)
            }
        }
    }

    private mutating func takeMember(_ part: String) {
        if let name = part.after(Part.alwaysSkipped) {
            alwaysSkipped.insert(name)
        } else if let place = part.after(Part.missingFoldersClosed).flatMap(Self.names) {
            missingFoldersClosed.insert(place)
        } else if let names = part.after(Part.namesKeptApart).flatMap(Self.names) {
            namesKeptApart.insert(names)
        }
    }

    /// A list of names as one part's name: its JSON.
    private static func member(_ names: [String]) -> String {
        (try? JSONEncoder().encode(names)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private static func names(_ member: String) -> [String]? {
        try? JSONDecoder().decode([String].self, from: Data(member.utf8))
    }
}

extension String {
    /// The rest after `prefix`, or nil when the string does not start with it.
    func after(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
