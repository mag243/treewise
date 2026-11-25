/// An item's state in its git repository, as a badge and the Git column show it
/// (ADR 0149). An unchanged item has none.
public enum GitItemState: String, Hashable, Sendable, CaseIterable {
    /// Changed since the last commit, staged or not; also a folder holding a change.
    case modified
    /// Not in the last commit at this place: untracked, added, or renamed or copied here.
    case new
    /// Matched by an ignore rule.
    case ignored
    /// Left with conflicts by a merge, a rebase or a cherry-pick.
    case conflict
}
