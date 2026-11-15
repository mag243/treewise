import AppKit
import TreewiseCore
import TreewiseUI

/// Asks the user what to do when a name is taken, in an alert: Replace, Keep Both or
/// Stop, with "Apply to All" for the rest of the operation (PLAN.md §4.2, ADR 0018).
/// `AskingConflictResolver` keeps the answer for all; one resolver serves one operation.
@MainActor
enum AlertConflictResolver {
    /// A resolver for one operation.
    static func make() -> AskingConflictResolver {
        AskingConflictResolver { item in ask(about: item) }
    }

    private static func ask(about item: FileItem) -> AskingConflictResolver.Answer {
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
        return AskingConflictResolver.Answer(
            decision: decision, appliesToAll: alert.suppressionButton?.state == .on)
    }
}
