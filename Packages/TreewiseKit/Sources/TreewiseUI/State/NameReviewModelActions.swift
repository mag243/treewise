import Foundation
import TreewiseCore

extension NameReviewModel {
    /// How many names around a new name show on each side.
    private static let neighbourReach = 2

    /// Moves a row to its next or previous option.
    public func step(_ id: FileItem.ID, by direction: StepDirection) {
        session?.step(id, by: direction)
        refreshConflicts()
    }

    /// Makes typed text a row's name.
    public func edit(_ id: FileItem.ID, to name: String) {
        session?.edit(id, to: name)
        refreshConflicts()
    }

    /// Ends typing in a row.
    public func finishEditing(_ id: FileItem.ID) {
        session?.finishEditing(id)
        refreshConflicts()
    }

    /// Approves a row's name, or says why that is not possible. A conflict stops it too.
    @discardableResult
    public func approve(_ id: FileItem.ID) -> NameReviewProblem? {
        if let conflict = conflicts[id] { return .conflict(conflict) }
        return session?.approve(id).map { .name($0) }
    }

    /// Leaves a row as it is.
    public func skip(_ id: FileItem.ID) {
        session?.skip(id)
        refreshConflicts()
    }

    /// Takes back a row's approval or skip.
    public func undecide(_ id: FileItem.ID) {
        session?.undecide(id)
        refreshConflicts()
    }

    /// Approves every row with a usable name and no date to look at.
    public func approveAll() {
        session?.approveAll(dateInFileIsReliable: dateInFileIsReliable, except: Set(conflicts.keys))
    }

    /// Approves every row with a usable name, dates to look at included.
    public func approveAllWithDatesToCheck() {
        session?.approveAll(
            dateInFileIsReliable: dateInFileIsReliable, includingDatesToCheck: true,
            except: Set(conflicts.keys))
    }

    /// How many rows only wait for a look at their date.
    public var datesToCheck: Int {
        session?.datesToCheck(dateInFileIsReliable: dateInFileIsReliable) ?? 0
    }

    /// Whether anything approved can be applied now.
    public var canApply: Bool {
        guard let renames = session?.approvedRenames, !renames.isEmpty else { return false }
        return renames.allSatisfy { conflicts[$0.item] == nil }
    }

    /// Applies the approved names. A folder that changed meanwhile can still stop a step,
    /// which `outcome` then reports.
    public func apply() async {
        guard canApply, let renames = session?.approvedRenames else { return }
        let names = (try? await dependencies.operations.contents(of: folder.id)) ?? folderItems
        let plan = BatchRenamePlanner.plan(renames, namesInFolders: [folder.id: names.map(\.name)])
        switch plan {
        case .conflicts(let found):
            folderItems = names
            conflicts = Dictionary(found.map { ($0.item, $0.kind) }) { first, _ in first }
        case .ready(let steps):
            outcome = await dependencies.operations.applyBatch(steps)
        }
    }

    /// The names around the selected row's name at its sorted place.
    public var neighbours: [NameNeighbours.Entry] {
        guard let id = selectedID, let entry = session?.entry(id) else { return [] }
        let name = entry.currentName ?? (entry.restsFitting ? entry.originalName : nil)
        guard let name else { return [] }
        let others = folderItems.filter { $0.id != id && !$0.isHidden }.map {
            ProposedName.shownName(fromDisk: $0.name)
        }
        return NameNeighbours.around(name, among: others, reach: Self.neighbourReach)
    }
}

/// Why a row cannot be approved.
public enum NameReviewProblem: Hashable, Sendable {
    /// The name itself cannot be used.
    case name(ProposedNameProblem)
    /// The name collides with another.
    case conflict(BatchRenameConflict.Kind)
}
