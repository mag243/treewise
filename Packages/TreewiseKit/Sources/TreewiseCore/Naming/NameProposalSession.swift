import Foundation

/// A review of proposed names: per item the ranked proposals, the choice, the
/// user's edit and a decision (ADR 0057). It holds no file system access and no
/// module; proposals arrive through `add(_:to:)`, in any order and at any time.
///
/// An unknown item is ignored: it may have gone from disk during the review.
public struct NameProposalSession: Hashable, Sendable {
    /// All items under review, in the order they were given.
    public private(set) var entries: [Entry]
    private let indexes: [FileItem.ID: Int]

    /// Creates a session for items.
    ///
    /// Precondition: the items have different ids.
    public init(items: [Entry]) {
        entries = items
        indexes = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
    }

    /// The entry of an item, or nil when it is not in this session.
    public func entry(_ id: FileItem.ID) -> Entry? {
        indexes[id].map { entries[$0] }
    }

    /// Adds proposals to an item. Invalid ones and ones equal to the current name
    /// are dropped. What the user chose, typed or approved stays as it is.
    public mutating func add(_ proposals: [NameProposal], to id: FileItem.ID) {
        update(id) { $0.add(proposals) }
    }

    /// Moves an item to its next or previous option. This needs a new approval.
    public mutating func step(_ id: FileItem.ID, by direction: StepDirection) {
        update(id) { $0.step(by: direction) }
    }

    /// Makes typed text the item's name. This needs a new approval.
    public mutating func edit(_ id: FileItem.ID, to name: String) {
        update(id) {
            $0.edit = name
            $0.selection = .edit
            $0.state = .pending
        }
    }

    /// Removes the item's edit and returns to its best proposal.
    public mutating func discardEdit(_ id: FileItem.ID) {
        update(id) {
            $0.edit = nil
            $0.selection = .none
            $0.state = .pending
            $0.add([])
        }
    }

    /// Approves the item's current name, or returns why that is not possible.
    @discardableResult
    public mutating func approve(_ id: FileItem.ID) -> ProposedNameProblem? {
        guard let problem = entry(id).map(\.problem) else { return .noName }
        if problem == nil { update(id) { $0.state = .approved } }
        return problem
    }

    /// Approves every pending item that has a usable name.
    public mutating func approveAll() {
        for entry in entries where entry.state == .pending { approve(entry.id) }
    }

    /// Leaves the item as it is.
    public mutating func skip(_ id: FileItem.ID) {
        update(id) { $0.state = .skipped }
    }

    /// The renames the approved items ask for, in the order of the items.
    public var approvedRenames: [BatchRename] {
        entries.compactMap { entry in
            guard entry.state == .approved, let name = entry.currentName else { return nil }
            return BatchRename(
                item: entry.id, folder: entry.folder, from: entry.originalName, to: name)
        }
    }

    private mutating func update(_ id: FileItem.ID, _ change: (inout Entry) -> Void) {
        guard let index = indexes[id] else { return }
        change(&entries[index])
    }
}
