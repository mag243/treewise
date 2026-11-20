import SwiftUI
import TreewiseCore
import TreewiseUI

/// New Folders from Template and Paste Structure… (ADR 0091, ADR 0095 to ADR 0097, ADR 0099)
/// over the Mac's model: the fields the tree holds, with what Treewise proposes, and the
/// folders they make, each new, already there or left out. A template rooted at `{year}`
/// chosen on a year's folder fills that folder itself, and the folder made remembers its
/// template (ADR 0141); a structure pasted is made inside, from no template.
struct NewFoldersFromTemplateSheet: View {
    let title: String
    /// The title where the width is compact, as on an iPhone, where the long one is cut off.
    let shortTitle: String
    let tree: FolderTree
    /// The saved template the folders come from; nil for a structure pasted.
    let template: FolderTemplate?
    let folder: FileItem.ID
    let browser: BrowserState
    let undoManager: UndoManager
    @State private var model: FolderTemplateSheetModel?
    /// The folders a file's name left out, said once the others are made.
    @State private var leftOut: [[String]] = []
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    NewFoldersForm(model: model)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text(sizeClass == .compact ? shortTitle : title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Folders") { Task { await create() } }
                        .disabled(model?.canCreate != true)
                }
            }
            .alert(
                String(localized: "Some folders were left out"),
                isPresented: Binding(get: { !leftOut.isEmpty }, set: { _ in dismiss() })
            ) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                let names = leftOut.map { "“\($0.joined(separator: "/"))”" }
                Text("A file has the name of \(names.formatted(.list(type: .and))).")
            }
        }
        .task { await start() }
    }

    private func start() async {
        let item = try? await browser.fileSystem.item(at: folder)
        let place: FolderTemplateSheetModel.Place
        if let item, let template, template.yearOfFolderItFills(named: item.name) != nil {
            place = .filling(item)
        } else {
            place = .inside(folder)
        }
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        let started = FolderTemplateSheetModel(
            template: tree, place: place, fileSystem: browser.fileSystem,
            currentYear: parts.year ?? 0,
            today: FolderTemplateValues.Day(
                year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1))
        await started.start()
        model = started
    }

    private func create() async {
        guard let model, let tree = model.tree, let madeIn = model.folderMadeIn,
            let outcome = await browser.createFolders(
                making: tree, in: madeIn, undoManager: undoManager)
        else { return }
        if let template {
            let root = FileItem.ID(madeIn.rawValue + "/" + tree.name)
            await NameServices.templateOrigins(for: browser).remember(
                made: root, from: template.id, yearBefore: nil)
        }
        if outcome.leftOut.isEmpty {
            dismiss()
        } else {
            leftOut = outcome.leftOut
        }
    }
}

/// The sheet's fields and the folders they make, following the model.
private struct NewFoldersForm: View {
    let model: FolderTemplateSheetModel

    /// The years a year's field steps through.
    private static let years = 1900...2099
    /// The highest number the number's field steps to.
    private static let mostNumber = 999_999
    /// How far a folder is set in for each level below the root.
    private static let indent: CGFloat = 20

    var body: some View {
        Form {
            if !model.fields.isEmpty {
                Section {
                    ForEach(model.fields, id: \.self, content: field)
                }
            }
            Section {
                ForEach(model.entries, id: \.path, content: entry)
            } footer: {
                summary
            }
        }
    }

    @ViewBuilder
    private func field(_ field: FolderTemplateField) -> some View {
        switch field {
        case .year:
            let year = model.values.year ?? Self.years.lowerBound
            Stepper(value: binding(year) { await model.setYear($0) }, in: Self.years) {
                LabeledContent(String(localized: "Year"), value: String(year))
            }
        case .number:
            let number = model.values.number?.value ?? 0
            Stepper(value: binding(number) { await model.setNumber($0) }, in: 0...Self.mostNumber) {
                LabeledContent(String(localized: "Number"), value: String(number))
            }
        case .text:
            TextField(
                String(localized: "Text"),
                text: binding(model.values.text ?? "") { await model.setText($0) },
                prompt: Text("Required")
            )
            .accessibilityIdentifier("templateText")
        case .date:
            DatePicker(
                String(localized: "Date"), selection: dateBinding, displayedComponents: .date)
        }
    }

    private func entry(_ entry: FolderTemplatePlan.Entry) -> some View {
        HStack {
            Label(entry.path.last ?? "", systemImage: "folder")
                .strikethrough(entry.state == .leftOut)
            Spacer()
            switch entry.state {
            case .new: EmptyView()
            case .existing: Text("already there").foregroundStyle(.tertiary)
            case .leftOut: Text("a file has this name · left out").foregroundStyle(.red)
            }
        }
        .padding(.leading, CGFloat(max(entry.path.count - 1, 0)) * Self.indent)
    }

    @ViewBuilder private var summary: some View {
        if let problem = model.problem {
            Text(TemplateProblemText.text(for: problem)).foregroundStyle(.red)
        } else if model.toMakeCount == 0 {
            Text("Every folder is already there.")
        } else {
            Text("Makes \(model.toMakeCount) folders.")
        }
    }

    private func binding<Value>(
        _ value: Value, set: @escaping @MainActor (Value) async -> Void
    ) -> Binding<Value> {
        Binding(get: { value }, set: { new in Task { await set(new) } })
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                guard let day = model.values.date else { return .now }
                let parts = DateComponents(year: day.year, month: day.month, day: day.day)
                return Calendar.current.date(from: parts) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
                let day = FolderTemplateValues.Day(
                    year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1)
                Task { await model.setDate(day) }
            })
    }
}
