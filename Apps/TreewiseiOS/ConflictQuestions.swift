import Observation
import TreewiseCore
import TreewiseUI

/// Asks the user what to do when a name is taken: Replace, Keep Both or Stop,
/// with "Apply to All" for the rest of the operation (PLAN.md §4.2, ADR 0047).
/// The folder view shows the question in a sheet.
@MainActor
@Observable
final class ConflictQuestions {
    typealias Answer = AskingConflictResolver.Answer

    /// The question the sheet shows, while an operation waits for its answer.
    private(set) var question: Question?

    /// A name taken by an incoming item, waiting for its answer.
    struct Question {
        let name: String
        fileprivate let answer: CheckedContinuation<Answer, Never>
    }

    /// A resolver for one operation, which remembers "Apply to All".
    func resolver() -> some ConflictResolving {
        AskingConflictResolver { item in await self.ask(about: item) }
    }

    /// Answers the question shown.
    func answer(_ decision: ConflictDecision, appliesToAll: Bool) {
        let question = question
        self.question = nil
        question?.answer.resume(
            returning: Answer(decision: decision, appliesToAll: appliesToAll))
    }

    private func ask(about item: FileItem) async -> Answer {
        if question != nil { answer(.stop, appliesToAll: false) }
        return await withCheckedContinuation { continuation in
            question = Question(name: item.name, answer: continuation)
        }
    }
}
