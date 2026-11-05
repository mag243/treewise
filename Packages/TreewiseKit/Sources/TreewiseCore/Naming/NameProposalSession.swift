import Foundation

/// A review of proposed names: per item the proposals in order, the choice, the
/// user's edit and a decision (ADR 0057). It holds no file system access and no
/// module; proposals arrive through `add(_:to:)`, in any order and at any time.
///
/// An unknown item is ignored: it may have gone from disk during the review.
public struct NameProposalSession: Hashable, Sendable {
    /// All items under review, in the order they were given.
    public private(set) var entries: [Entry]
    /// The modules that are on, which order an item's proposals.
    public private(set) var moduleOrder: [String]
    private let indexes: [FileItem.ID: Int]

    /// Creates a session for items.
    ///
    /// Precondition: the items have different ids.
    public init(items: [Entry], moduleOrder: [String]) {
        entries = items
        self.moduleOrder = moduleOrder
        indexes = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
    }

    /// The entry of an item, or nil when it is not in this session.
    public func entry(_ id: FileItem.ID) -> Entry? {
        indexes[id].map { entries[$0] }
    }

    /// Adds proposals to an item. Invalid ones and ones equal to the current name
    /// are dropped. What the user chose, typed or approved stays as it is.
    public mutating func add(_ proposals: [NameProposal], to id: FileItem.ID) {
        let order = moduleOrder
        update(id) { $0.add(proposals, moduleOrder: order) }
    }

    /// Replaces what one module proposed for an item, as after a change of its
    /// template. An approved name stays, as the user's own.
    public mutating func replaceProposals(
        _ proposals: [NameProposal], from moduleID: String, for id: FileItem.ID
    ) {
        let order = moduleOrder
        update(id) { $0.replaceProposals(proposals, from: moduleID, moduleOrder: order) }
    }

    /// Moves an item to its next or previous option. This needs a new approval.
    public mutating func step(_ id: FileItem.ID, by direction: StepDirection) {
        update(id) { $0.step(by: direction) }
    }

    /// Makes typed text the item's name. This needs a new approval. It keeps the text
    /// as typed until `finishEditing(_:)`, so the options do not shift during typing.
    public mutating func edit(_ id: FileItem.ID, to name: String) {
        update(id) {
            $0.edit = name
            $0.selection = .edit
            $0.state = .pending
        }
    }

    /// Ends an edit, when the user leaves the field: an empty one goes away, and one
    /// exactly equal to a proposal merges with it.
    public mutating func finishEditing(_ id: FileItem.ID) {
        update(id) { $0.finishEditing() }
    }

    /// Removes the item's edit and returns to its best proposal.
    public mutating func discardEdit(_ id: FileItem.ID) {
        update(id) { $0.discardEdit() }
    }

    /// Records which modules' templates the item's name fits.
    public mutating func setFit(_ id: FileItem.ID, moduleIDs: [String]) {
        let order = moduleOrder
        update(id) { entry in
            entry.fittingModuleIDs = order.filter(moduleIDs.contains)
        }
    }

    /// Records whether no module that is on handles the item.
    public mutating func setOutOfScope(_ id: FileItem.ID, _ isOutOfScope: Bool) {
        update(id) { $0.isOutOfScope = isOutOfScope }
    }

    /// Approves the item's current name, or returns why that is not possible.
    @discardableResult
    public mutating func approve(_ id: FileItem.ID) -> ProposedNameProblem? {
        guard let problem = entry(id).map(\.problem) else { return .noName }
        if problem == nil { update(id) { $0.state = .approved } }
        return problem
    }

    /// Approves every pending item that has a usable name and no date to look at. A
    /// date from the file system always needs a look; one inside the file does unless
    /// it proved reliable in this folder.
    public mutating func approveAll(dateInFileIsReliable: Bool) {
        for entry in entries where entry.state == .pending {
            switch entry.currentDateSource {
            case .fileSystem: continue
            case .insideFile where !dateInFileIsReliable: continue
            default: approve(entry.id)
            }
        }
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
                item: entry.id, folder: entry.folder, from: entry.originalName,
                to: ProposedName.diskName(fromShown: name))
        }
    }

    private mutating func update(_ id: FileItem.ID, _ change: (inout Entry) -> Void) {
        guard let index = indexes[id] else { return }
        change(&entries[index])
    }
}
