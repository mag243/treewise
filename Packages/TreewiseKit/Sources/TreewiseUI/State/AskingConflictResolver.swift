import TreewiseCore

/// Resolves the name conflicts of one operation by asking the user: Replace, Keep Both or
/// Stop, with "Apply to All" for the rest of the operation (PLAN.md §4.2). Each app asks
/// in its own way, an alert on the Mac and a sheet on the iPad; the answer for all is
/// kept here, so both keep it alike. One resolver serves one operation.
@MainActor
public final class AskingConflictResolver: ConflictResolving {
    /// The decision the user took, and whether it holds for the rest of the operation.
    public struct Answer: Sendable {
        public let decision: ConflictDecision
        public let appliesToAll: Bool

        public init(decision: ConflictDecision, appliesToAll: Bool) {
            self.decision = decision
            self.appliesToAll = appliesToAll
        }
    }

    private let ask: @MainActor (FileItem) async -> Answer
    private var answerForAll: ConflictDecision?

    /// A resolver that asks about an incoming item with `ask`, until an answer applies
    /// to all.
    public init(ask: @escaping @MainActor (FileItem) async -> Answer) {
        self.ask = ask
    }

    public nonisolated func decide(existing: FileItem, incoming: FileItem) async
        -> ConflictDecision
    {
        await decide(about: incoming)
    }

    private func decide(about item: FileItem) async -> ConflictDecision {
        if let answerForAll { return answerForAll }
        let answer = await ask(item)
        if answer.appliesToAll { answerForAll = answer.decision }
        return answer.decision
    }
}
