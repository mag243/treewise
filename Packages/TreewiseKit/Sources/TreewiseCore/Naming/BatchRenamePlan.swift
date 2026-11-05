/// What planning a batch of renames gives: all steps, or all reasons not to start
/// (ADR 0057). A plan never holds both, so no conflict is found halfway.
public enum BatchRenamePlan: Hashable, Sendable {
    /// The steps, in the order they must run.
    case ready([BatchRenameStep])
    /// What stands in the way, in the order of the renames.
    case conflicts([BatchRenameConflict])
}

/// One rename to run. In a cycle an item takes two steps, through a temporary name.
public struct BatchRenameStep: Hashable, Sendable {
    /// The item, identified as it was before the batch started.
    public let item: FileItem.ID
    /// The name it has when this step runs.
    public let from: String
    /// The name it has after this step.
    public let to: String

    /// Creates a step.
    public init(item: FileItem.ID, from: String, to: String) {
        self.item = item
        self.from = from
        self.to = to
    }
}

/// Why an item cannot get its approved name.
public struct BatchRenameConflict: Hashable, Sendable {
    /// What the name collides with.
    public enum Kind: Hashable, Sendable {
        /// Another item in the batch wants the same name in the same folder.
        case duplicateInBatch
        /// An item that stays in the folder has this name.
        case nameTaken(String)
    }

    /// The item.
    public let item: FileItem.ID
    /// What the name collides with.
    public let kind: Kind

    /// Creates a conflict.
    public init(item: FileItem.ID, kind: Kind) {
        self.item = item
        self.kind = kind
    }
}
