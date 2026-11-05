import SwiftUI
import TreewiseCore
import TreewiseUI

/// The overview of proposed names: the add-ons, the list and the panel beside it.
struct NameReviewView: View {
    private static let panelWidth: CGFloat = 300

    @Bindable var model: NameReviewModel
    let browser: BrowserState
    let undoManager: UndoManager?
    let close: () -> Void

    @AppStorage("nameReviewAddOnsOpen") private var addOnsOpen = true
    @AppStorage("nameReviewShowsPanel") private var showsPanel = true
    @State private var showsHiddenRows = false
    @State private var wasToggled = false
    @State private var isOpenNow = false

    private var panelIsOpen: Binding<Bool> {
        Binding(
            get: { wasToggled ? isOpenNow : (model.isFirstReview || addOnsOpen) },
            set: { isOpen in
                wasToggled = true
                isOpenNow = isOpen
                addOnsOpen = isOpen
            })
    }

    var body: some View {
        VStack(spacing: 0) {
            if let outcome = model.outcome {
                NameReviewResultView(
                    outcome: outcome, model: model, undoManager: undoManager, close: close)
            } else {
                NameReviewAddOnsView(model: model, isOpen: panelIsOpen)
                Divider()
                HStack(spacing: 0) {
                    NameReviewListView(model: model, showsHidden: $showsHiddenRows)
                        .frame(maxWidth: .infinity)
                    if showsPanel {
                        Divider()
                        NameReviewPanelView(model: model).frame(width: Self.panelWidth)
                    }
                }
                Divider()
                footer
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(summary).foregroundStyle(.secondary)
            Text("Add-ons see only files they handle, and cannot reach the internet.")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
            Button(showsPanel ? "Hide Preview" : "Show Preview") { showsPanel.toggle() }
            if model.datesToCheck > 0 {
                Button("Approve \(model.datesToCheck) with Dates to Check") {
                    model.approveAllWithDatesToCheck()
                }
            }
            Button("Approve All") { model.approveAll() }
            Button("Cancel", role: .cancel, action: close)
            Button(applyTitle) { apply() }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!model.canApply)
        }
        .padding(10)
    }

    private var approvedCount: Int { model.session?.approvedRenames.count ?? 0 }

    private var summary: String {
        String(localized: "\(approvedCount) of \(model.rows.count) approved")
    }

    private var applyTitle: String {
        approvedCount == 0
            ? String(localized: "Rename") : String(localized: "Rename \(approvedCount) Items")
    }

    private func apply() {
        Task {
            await model.apply()
            if let outcome = model.outcome {
                await browser.finishNameReview(outcome, undoManager: undoManager)
            }
        }
    }
}

/// What applying did, and the way back.
struct NameReviewResultView: View {
    let outcome: BatchRenameOutcome
    let model: NameReviewModel
    let undoManager: UndoManager?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(outcome.renamed.count) items renamed").font(.headline)
            if let failure = outcome.failure {
                Label(failureText(failure), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            List(outcome.renamed, id: \.original) { renamed in
                Text(renamed.item.name).textSelection(.enabled)
            }
            HStack {
                Spacer()
                Button("Undo Rename") {
                    undoManager?.undo()
                    close()
                }
                Button("Done", action: close).keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }

    private func failureText(_ failure: BatchRenameOutcome.Failure) -> String {
        if let temporary = failure.leftUnderTemporaryName {
            return String(
                localized:
                    "Stopped: a name could not be given. A file is left as \(temporary); Undo Rename puts it back."
            )
        }
        return String(
            localized: "Stopped: a name could not be given, and the rest stayed as it was.")
    }
}
