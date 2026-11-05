import Observation
import TreewiseCore

/// Asks the user what to do when a name is taken: Replace, Keep Both or Stop,
/// with "Apply to All" for the rest of the operation (PLAN.md §4.2, ADR 0047).
/// The folder view shows the question in a sheet.
@MainActor
@Observable
final class ConflictQuestions {
    /// The question the sheet shows, while an operation waits for its answer.
    private(set) var question: Question?

    /// A name taken by an incoming item, waiting for its answer.
    struct Question {
        let name: String
        fileprivate let answer: CheckedContinuation<Answer, Never>
    }

    /// The decision, and whether it holds for the rest of the operation.
    struct Answer {
        let decision: ConflictDecision
        let appliesToAll: Bool
    }

    /// A resolver for one operation, which remembers "Apply to All".
    func resolver() -> some ConflictResolving {
        OperationResolver(questions: self)
    }

    /// Answers the question shown.
    func answer(_ decision: ConflictDecision, appliesToAll: Bool) {
        let question = question
        self.question = nil
        question?.answer.resume(returning: Answer(decision: decision, appliesToAll: appliesToAll))
    }

    fileprivate func ask(about item: FileItem) async -> Answer {
        if question != nil { answer(.stop, appliesToAll: false) }
        return await withCheckedContinuation { continuation in
            question = Question(name: item.name, answer: continuation)
        }
    }
}

/// Resolves the conflicts of one operation by asking the user, until an
/// answer applies to all.
@MainActor
private final class OperationResolver: ConflictResolving {
    private let questions: ConflictQuestions
    private var answerForAll: ConflictDecision?

    init(questions: ConflictQuestions) {
        self.questions = questions
    }

    nonisolated func decide(existing: FileItem, incoming: FileItem) async -> ConflictDecision {
        await decide(about: incoming)
    }

    private func decide(about item: FileItem) async -> ConflictDecision {
        if let answerForAll { return answerForAll }
        let answer = await questions.ask(about: item)
        if answer.appliesToAll { answerForAll = answer.decision }
        return answer.decision
    }
}
