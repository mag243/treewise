import Foundation
import TreewiseCore
import UniformTypeIdentifiers

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

    /// Answers a key on the selected row, and says whether it did. While the user types
    /// in a name, keys belong to the text.
    public func handle(_ key: NameReviewKey, isTyping: Bool) -> Bool {
        guard !isTyping, let id = selectedID else { return false }
        switch key {
        case .approve:
            approve(id)
            moveDown(from: id)
        case .skip:
            skip(id)
            moveDown(from: id)
        case .next:
            step(id, by: .next)
        case .previous:
            step(id, by: .previous)
        }
        return true
    }

    private func moveDown(from id: FileItem.ID) {
        let shown = rows
        guard let index = shown.firstIndex(where: { $0.id == id }), index + 1 < shown.count else {
            return
        }
        selectedID = shown[index + 1].id
    }

    /// Takes back a row's approval or skip.
    public func undecide(_ id: FileItem.ID) {
        session?.undecide(id)
        refreshConflicts()
    }

    /// Whether the item is a photo, whose date inside the file is the capture date. The
    /// other files that give such a date are PDFs (ADR 0057).
    public func isPhoto(_ id: FileItem.ID) -> Bool {
        guard let type = facts[id].flatMap({ UTType($0.contentType) }) else { return false }
        return type.conforms(to: .image)
    }

    /// Approves every row with a usable name, a date to check included (ADR 0058). A name
    /// with personal data is left out unless the user chose only a warning (ADR 0060).
    public func approveAll() {
        var excluded = Set(conflicts.keys)
        if dependencies.personalDataInNames == .leaveOutOfApproveAll, let session {
            excluded.formUnion(session.entries.filter { !$0.personalData.isEmpty }.map(\.id))
        }
        session?.approveAll(except: excluded)
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

/// A key the overview's list answers to.
public enum NameReviewKey: Hashable, Sendable {
    /// Approve the row and go down.
    case approve
    /// Skip the row and go down.
    case skip
    /// The row's next option.
    case next
    /// The row's previous option.
    case previous
}

/// Why a row cannot be approved.
public enum NameReviewProblem: Hashable, Sendable {
    /// The name itself cannot be used.
    case name(ProposedNameProblem)
    /// The name collides with another.
    case conflict(BatchRenameConflict.Kind)
}
