import AppKit
import TreewiseCore

/// Asks the user what to do when a name is taken: Replace, Keep Both or Stop,
/// with "Apply to All" for the rest of the operation (PLAN.md §4.2, ADR 0018).
/// One resolver serves one operation.
@MainActor
final class AlertConflictResolver: ConflictResolving {
    private var answerForAll: ConflictDecision?

    nonisolated func decide(existing: FileItem, incoming: FileItem) async -> ConflictDecision {
        await ask(about: incoming)
    }

    private func ask(about item: FileItem) -> ConflictDecision {
        if let answerForAll { return answerForAll }
        let alert = NSAlert()
        alert.messageText = String(
            localized: "An item named “\(item.name)” already exists in this location.",
            comment: "Conflict dialog title")
        alert.informativeText = String(
            localized: "Do you want to replace it with the one you’re moving or copying?",
            comment: "Conflict dialog text")
        alert.addButton(
            withTitle: String(localized: "Keep Both", comment: "Conflict dialog button"))
        alert.addButton(withTitle: String(localized: "Replace", comment: "Conflict dialog button"))
        alert.addButton(withTitle: String(localized: "Stop", comment: "Conflict dialog button"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = String(
            localized: "Apply to All", comment: "Conflict dialog checkbox")
        let decision: ConflictDecision =
            switch alert.runModal() {
            case .alertFirstButtonReturn: .keepBoth
            case .alertSecondButtonReturn: .replace
            default: .stop
            }
        if alert.suppressionButton?.state == .on { answerForAll = decision }
        return decision
    }
}
