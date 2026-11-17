import SwiftUI
import TreewiseCore
import TreewiseUI

/// A name overview being shown, for `fullScreenCover(item:)`.
struct NameReviewShown: Identifiable {
    let id = UUID()
    let model: NameReviewModel
}

/// The name overview on the iPad (ADR 0129), as the Mac's in iPad form: the patterns at the
/// top, the files with their proposals beneath, Cancel and Rename in the bar, and how many
/// are approved with Approve All at the bottom.
struct NameReviewSheet: View {
    let model: NameReviewModel
    let browser: BrowserState
    let undoManager: UndoManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let problem = NameReviewText.text(
                    model.startProblem, moduleFailed: model.moduleFailed)
                {
                    Section {
                        Label(problem, systemImage: "exclamationmark.triangle")
                        Button("Try Again") { Task { await model.retry() } }
                    }
                }
                Section { NameReviewPatterns(model: model) }
                Section {
                    ForEach(model.rows) { entry in
                        NameReviewRow(model: model, entry: entry)
                    }
                } footer: {
                    if !model.hiddenRows.isEmpty { Text(hiddenSummary) }
                }
            }
            .overlay { placeholder }
            .navigationTitle(Text("Suggest Names: \(model.folder.name)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
        }
        .onDisappear { model.stop() }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(renameTitle) { rename() }
                .disabled(!model.canApply)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Text("\(approved) of \(model.rows.count) approved")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Approve All") { model.approveAll() }
                .disabled(model.rows.isEmpty)
        }
    }

    @ViewBuilder private var placeholder: some View {
        if model.rows.isEmpty, model.readingCount == 0, model.startProblem == nil {
            if model.session != nil {
                ContentUnavailableView(
                    String(localized: "No files to name"), systemImage: "doc.text")
            }
        }
    }

    private var approved: Int {
        model.rows.filter { $0.state == .approved }.count
    }

    private var renameTitle: String {
        approved <= 1 ? String(localized: "Rename") : String(localized: "Rename \(approved) Items")
    }

    /// What lies behind the line: files that already fit, and those always skipped.
    private var hiddenSummary: String {
        let skipped = model.hiddenRows.filter { model.isAlwaysSkipped($0.id) }.count
        let fitting = model.hiddenRows.count - skipped
        return skipped == 0
            ? String(localized: "\(fitting) files already fit")
            : String(localized: "\(fitting) files already fit, \(skipped) always skipped")
    }

    private func rename() {
        Task {
            await model.apply()
            guard let outcome = model.outcome else { return }
            await browser.finishNameReview(outcome, undoManager: undoManager)
            dismiss()
        }
    }
}
