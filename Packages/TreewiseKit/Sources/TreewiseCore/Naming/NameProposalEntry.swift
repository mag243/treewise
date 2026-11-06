import Foundation

extension NameProposalSession {
    /// One item under review. `Invariant:` `proposals` follows the order of the
    /// modules and each module's ranking, holds no two names the file system treats
    /// as the same, and holds only names that passed `ProposedName`.
    public struct Entry: Identifiable, Hashable, Sendable {
        /// Where an item stands in the review.
        public enum State: Hashable, Sendable {
            /// Not decided yet.
            case pending
            /// To be renamed to the current name.
            case approved
            /// To be left as it is.
            case skipped
        }

        /// A valid name among the options of an item.
        public struct Option: Hashable, Sendable {
            /// The full name, with its extension.
            public internal(set) var name: String
            /// The modules that proposed it, in their order.
            public internal(set) var moduleIDs: [String]
            /// Where its date comes from, or nil when it has no suggested date.
            public internal(set) var dateSource: NameProposal.DateSource?
        }

        /// Which of the options is current.
        enum Selection: Hashable, Sendable {
            case none
            case proposal(key: String)
            case edit
        }

        /// Where the current name stands among the options, for "2 of 3".
        public struct Position: Hashable, Sendable {
            /// The current option's index, from 0.
            public let index: Int
            /// How many options there are.
            public let count: Int

            /// Creates a position.
            public init(index: Int, count: Int) {
                self.index = index
                self.count = count
            }
        }

        /// The item.
        public let id: FileItem.ID
        /// The folder that holds the item.
        public let folder: FileItem.ID
        /// The name the item has now.
        public let originalName: String
        /// The item's kind, which decides whether it has an extension.
        public let kind: ItemKind
        /// The proposals so far, in order.
        public internal(set) var proposals: [Option] = []
        /// What the user typed, if anything. It stays an option while stepping.
        public internal(set) var edit: String?
        /// Where the item stands in the review.
        public internal(set) var state = State.pending
        /// The modules whose templates the current name fits, in their order.
        public internal(set) var fittingModuleIDs: [String] = []
        /// Whether no module that is on handles this item, which then stays as it is.
        public internal(set) var isOutOfScope = false
        var selection = Selection.none

        /// Creates an entry without proposals.
        public init(id: FileItem.ID, folder: FileItem.ID, originalName: String, kind: ItemKind) {
            self.id = id
            self.folder = folder
            self.originalName = originalName
            self.kind = kind
        }

        /// The name currently chosen, or nil before there is one.
        public var currentName: String? {
            switch selection {
            case .none: nil
            case .edit: edit
            case .proposal(let key): proposals.first { Self.key($0.name) == key }?.name
            }
        }

        /// Whether the item fits a template and nothing else is proposed, so it
        /// needs no decision.
        public var restsFitting: Bool {
            !fittingModuleIDs.isEmpty && proposals.isEmpty && edit == nil
        }

        /// Why the current name cannot be approved, or nil when it can.
        public var problem: ProposedNameProblem? {
            guard !isOutOfScope, let name = currentName else { return .noName }
            if name == ProposedName.shownName(fromDisk: originalName) { return .unchanged }
            if name.contains(NameTemplate.gap) { return .hasGap }
            return ProposedName.problem(inEdit: name)
        }

        /// Where the current name's date comes from, or nil when it has no suggested date.
        public var currentDateSource: NameProposal.DateSource? {
            guard case .proposal(let key) = selection else { return nil }
            return proposals.first { Self.key($0.name) == key }?.dateSource
        }

        /// The personal data in the chosen proposal (ADR 0060). A name the user typed is
        /// left alone, because the user wrote it on purpose.
        public var personalData: [PersonalData] {
            guard case .proposal = selection, let name = currentName else { return [] }
            return PersonalData.found(in: name)
        }

        /// The current name's place among the options, or nil before there is one.
        public var position: Position? {
            guard let index = selectedIndex else { return nil }
            return Position(index: index, count: optionCount)
        }

        private var optionCount: Int { proposals.count + (edit == nil ? 0 : 1) }

        private var selectedIndex: Int? {
            switch selection {
            case .none: nil
            case .edit: proposals.count
            case .proposal(let key): proposals.firstIndex { Self.key($0.name) == key }
            }
        }

        /// Moves to the next or previous option, wrapping around.
        mutating func step(by direction: StepDirection) {
            guard let index = selectedIndex, optionCount > 0 else { return }
            let next = (index + direction.offset + optionCount) % optionCount
            selection =
                next < proposals.count ? .proposal(key: Self.key(proposals[next].name)) : .edit
            state = .pending
        }

        /// The form two names share when the file system treats them as the same.
        static func key(_ name: String) -> String {
            ConflictResolver.comparisonKey(name)
        }
    }
}
