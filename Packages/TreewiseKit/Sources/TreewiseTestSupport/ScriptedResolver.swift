import Synchronization
import TreewiseCore

/// A conflict resolver that gives its answers in order, then repeats the last,
/// and records which conflicts it was asked about.
public final class ScriptedResolver: ConflictResolving {
    private let answers: Mutex<(pending: [ConflictDecision], asked: [String])>

    /// Creates a resolver that answers with `decisions`, in order.
    public init(_ decisions: ConflictDecision...) {
        answers = Mutex((decisions, []))
    }

    /// The names it was asked about, in order.
    public var askedNames: [String] {
        answers.withLock { $0.asked }
    }

    public func decide(existing: FileItem, incoming: FileItem) async -> ConflictDecision {
        answers.withLock { state in
            state.asked.append(incoming.name)
            let answer = state.pending.first ?? .stop
            if state.pending.count > 1 { state.pending.removeFirst() }
            return answer
        }
    }
}
