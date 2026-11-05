/// What a drop or paste does with the items.
public enum TransferMode: Sendable, Hashable {
    /// The items leave their folder; across volumes this is copy and then delete.
    case move
    /// The items stay where they are and a copy lands in the target.
    case copy
}
