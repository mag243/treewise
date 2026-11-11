import Observation

/// Follows observable state from AppKit: runs `update` now, and again after
/// each change of what it read, for as long as `owner` lives.
@MainActor
enum Observing {
    static func follow<Owner: AnyObject & Sendable>(
        _ owner: Owner, _ update: @escaping @MainActor @Sendable (Owner) -> Void
    ) {
        withObservationTracking {
            update(owner)
        } onChange: { [weak owner] in
            Task { @MainActor in
                if let owner { follow(owner, update) }
            }
        }
    }
}
