/// A direction through an item's proposed names (ADR 0057).
public enum StepDirection: Hashable, Sendable {
    /// Towards the next option.
    case next
    /// Towards the previous option.
    case previous

    var offset: Int {
        switch self {
        case .next: 1
        case .previous: -1
        }
    }
}
