/// What a review of names looks at and what it reads (ADR 0057). Templates are judged
/// here, without a module and without reading a file, so a whole folder reads only
/// what does not fit yet.
public enum NameReviewRules {
    /// What the user opened the review for.
    public enum Scope: Hashable, Sendable {
        /// The files directly in a folder.
        case wholeFolder
        /// Items the user selected.
        case selection
    }

    /// A module that is on, with its template for this folder.
    public struct Module: Hashable, Sendable {
        /// The module's id.
        public let id: String
        /// Its template for this folder.
        public let template: NameTemplate

        /// Creates a module.
        public init(id: String, template: NameTemplate) {
            self.id = id
            self.template = template
        }
    }

    /// What happens to one item in a review.
    public struct Plan: Hashable, Sendable {
        /// The modules whose templates the name fits.
        public let fittingModules: [String]
        /// The modules to ask for values, which reads the item if they need contents.
        public let modulesToAsk: [String]
        /// Whether no module that is on handles the item.
        public let isOutOfScope: Bool
        /// Whether it stays behind the line under the table.
        public let isHidden: Bool
        /// Whether the user chose to always skip it in a whole-folder review.
        public let isAlwaysSkipped: Bool
        /// The same name with its stray spaces repaired, if the rest of it fits.
        public let repair: NameProposal?
    }

    /// The item under review.
    public struct Item: Hashable, Sendable {
        /// Its name on disk.
        public let name: String
        /// Its kind.
        public let kind: ItemKind
        /// The ids of the modules that handle its type.
        public let handledBy: [String]

        /// Creates an item.
        public init(name: String, kind: ItemKind, handledBy: [String]) {
            self.name = name
            self.kind = kind
            self.handledBy = handledBy
        }
    }

    /// The folder that holds the item.
    public struct Folder: Hashable, Sendable {
        /// Its name.
        public let name: String
        /// The names of the folders above it, nearest first, for `{folder:2}` and higher
        /// (ADR 0089).
        public let foldersAbove: [String]
        /// The names the user always skips in it, on disk.
        public let alwaysSkipped: Set<String>

        /// Creates a folder.
        public init(name: String, alwaysSkipped: Set<String>, foldersAbove: [String] = []) {
            self.name = name
            self.foldersAbove = foldersAbove
            self.alwaysSkipped = alwaysSkipped
        }
    }

    /// Decides what happens to an item, or nil when a whole-folder review leaves it out.
    /// `modules` are those that are on, in their order.
    public static func plan(
        for item: Item, in folder: Folder, scope: Scope, modules: [Module]
    ) -> Plan? {
        let (name, kind) = (item.name, item.kind)
        if scope == .wholeFolder, kind.isContainer { return nil }
        let shown = ProposedName.shownName(fromDisk: name)
        let handling = modules.filter { item.handledBy.contains($0.id) }
        let fixed = NameTemplate.folderValues([folder.name] + folder.foldersAbove)
        let fits = { (candidate: String, module: Module) in
            module.template.matches(ConflictResolver.split(candidate, kind: kind).0, fixed: fixed)
        }
        let fitting = handling.filter { fits(shown, $0) }.map(\.id)
        let repair = ProposedName.repairingSpaces(in: shown).flatMap { repaired in
            handling.contains { fits(repaired, $0) }
                ? NameProposal(name: repaired, moduleID: NameProposal.treewiseID) : nil
        }
        let skipped = scope == .wholeFolder && folder.alwaysSkipped.contains(name)
        let hidden = scope == .wholeFolder && (skipped || !fitting.isEmpty)
        let waits = hidden || (scope == .wholeFolder && repair != nil)
        return Plan(
            fittingModules: fitting, modulesToAsk: waits ? [] : handling.map(\.id),
            isOutOfScope: handling.isEmpty, isHidden: hidden, isAlwaysSkipped: skipped,
            repair: repair)
    }
}
