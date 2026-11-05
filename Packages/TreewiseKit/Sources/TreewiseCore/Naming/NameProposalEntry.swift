import Foundation

extension NameProposalSession {
    /// One item under review. `Invariant:` `proposals` is sorted by falling
    /// confidence, holds no two names the file system treats as the same, and
    /// holds only names that passed `ProposedName`.
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
            public let name: String
            /// The module that proposed it.
            public let moduleID: String
            /// How sure the module is, from 0 to 1.
            public let confidence: Double
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
        /// The proposals so far, best first.
        public internal(set) var proposals: [Option] = []
        /// What the user typed, if anything. It stays an option while stepping.
        public internal(set) var edit: String?
        /// Where the item stands in the review.
        public internal(set) var state = State.pending
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

        /// Why the current name cannot be approved, or nil when it can.
        public var problem: ProposedNameProblem? {
            guard let name = currentName else { return .noName }
            if name == originalName { return .unchanged }
            return ProposedName.problem(inEdit: name)
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

        /// Adds proposals without changing what is chosen, except that the first
        /// valid proposal becomes the choice while there is none.
        mutating func add(_ newProposals: [NameProposal]) {
            for proposal in newProposals { add(proposal) }
            // Sorting is stable, so names of equal confidence keep their arrival order.
            proposals.sort { $0.confidence > $1.confidence }
            if selection == .none, let best = proposals.first {
                selection = .proposal(key: Self.key(best.name))
            }
        }

        private mutating func add(_ proposal: NameProposal) {
            guard
                case .success(let name) = ProposedName.resolve(
                    proposal, for: originalName, kind: kind),
                name != originalName
            else { return }
            let option = Option(
                name: name, moduleID: proposal.moduleID, confidence: proposal.confidence)
            let key = Self.key(name)
            guard let index = proposals.firstIndex(where: { Self.key($0.name) == key }) else {
                proposals.append(option)
                return
            }
            if option.confidence > proposals[index].confidence { proposals[index] = option }
        }

        /// The form two names share when the file system treats them as the same.
        private static func key(_ name: String) -> String {
            ConflictResolver.comparisonKey(name)
        }
    }
}
