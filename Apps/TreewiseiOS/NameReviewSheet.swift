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
/// are approved with Approve All at the bottom. Where the screen is wide, as an iPad in
/// landscape, the panel about the chosen file shows beside the list, as on the Mac, with Show
/// and Hide Preview; elsewhere a row's ⓘ shows it in a sheet.
struct NameReviewSheet: View {
    let model: NameReviewModel
    let browser: BrowserState
    let settings: BrowserSettings
    let undoManager: UndoManager
    @Environment(\.dismiss) private var dismiss
    @State private var showsPanel = true
    @State private var isShowingDetails = false
    @State private var isEditingSaved = false

    /// The least width that holds the list and the panel beside it: an iPad in landscape.
    private static let panelMinimumWidth: CGFloat = 1100
    /// The panel's width beside the list.
    private static let panelWidth: CGFloat = 360

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isWide = geometry.size.width >= Self.panelMinimumWidth
                HStack(spacing: 0) {
                    list(isWide: isWide)
                    if isWide, showsPanel {
                        Divider()
                        NameReviewDetails(model: model).frame(width: Self.panelWidth)
                    }
                }
                .toolbar { toolbar(isWide: isWide) }
            }
            .navigationTitle(Text("Suggest Names: \(model.folder.name)"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isShowingDetails) {
            NavigationStack {
                NameReviewDetails(model: model)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingDetails = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $isEditingSaved) {
            NavigationStack {
                SavedPatternsList(settings: settings)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isEditingSaved = false }
                        }
                    }
            }
        }
        .onDisappear { model.stop() }
    }

    private func list(isWide: Bool) -> some View {
        List {
            if let problem = NameReviewText.text(
                model.startProblem, moduleFailed: model.moduleFailed)
            {
                Section {
                    Label(problem, systemImage: "exclamationmark.triangle")
                    Button("Try Again") { Task { await model.retry() } }
                }
            }
            Section { NameReviewPatterns(model: model) { isEditingSaved = true } }
            Section {
                ForEach(model.rows) { entry in
                    NameReviewRow(
                        model: model, entry: entry,
                        showDetails: isWide && showsPanel ? nil : { isShowingDetails = true })
                }
            } footer: {
                if !model.hiddenRows.isEmpty { Text(hiddenSummary) }
            }
        }
        .overlay { placeholder }
    }

    @ToolbarContentBuilder private func toolbar(isWide: Bool) -> some ToolbarContent {
        if isWide {
            ToolbarItem(placement: .primaryAction) {
                Button(
                    showsPanel
                        ? String(localized: "Hide Preview") : String(localized: "Show Preview")
                ) { showsPanel.toggle() }
            }
        }
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
        if model.rows.isEmpty, model.startProblem == nil, !model.moduleFailed {
            if model.session == nil || model.readingCount > 0 {
                // The files are still being read, as from a cloud provider.
                ProgressView { Text("Reading the files…") }
                    .accessibilityIdentifier("reading")
            } else {
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
