import SwiftUI
import TreewiseCore
import TreewiseUI

/// Rename in All Years… (ADR 0139) over the Mac's model: on a folder inside a year's own
/// folder, the new name, each year's folder with its old and new name and a switch, the years
/// left out with why, and a switch for each template corrected along (ADR 0141). One Undo
/// takes it all back.
struct RenameInAllYearsSheet: View {
    let folder: FileItem
    let browser: BrowserState
    let undoManager: UndoManager
    @State private var model: RenameInAllYearsModel?
    /// Why a folder could not be renamed, while that is said.
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    RenameInAllYearsForm(model: model, show: show)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text("Rename “\(folder.name)” in All Years"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(renameTitle) { Task { await rename() } }
                        .disabled(model?.canRename != true)
                        .accessibilityIdentifier("renameInAllYearsRename")
                }
            }
            .alert(
                failure ?? "",
                isPresented: Binding(get: { failure != nil }, set: { _ in dismiss() })
            ) {
                Button("OK", role: .cancel) { dismiss() }
            }
        }
        .task { await start() }
    }

    private var renameTitle: String {
        guard let model, model.trimmedName != model.oldName else {
            return String(localized: "Rename")
        }
        return String(localized: "Rename \(model.renames.count) Folders")
    }

    private func start() async {
        let templates = NameServices.templateList
        await templates.load()
        model = await RenameInAllYearsModel.make(
            for: folder, in: browser.fileSystem, templates: templates.templates,
            madeFrom: {
                await NameServices.folderSettings.settings(forFolderAt: $0.rawValue)?.madeFrom
                    ?? []
            })
        if model == nil { dismiss() }
    }

    private func rename() async {
        guard let model else { return }
        let result = await browser.renameInAllYears(
            model, templates: NameServices.templateList, settings: NameServices.folderSettings,
            undoManager: undoManager)
        guard case .stopped(let stopped, _) = result else {
            dismiss()
            return
        }
        let place = model.places.first { $0.folder == stopped.item }
        failure =
            place.map {
                String(localized: "“\($0.name)” in \(model.label(of: $0)) could not be renamed")
            } ?? String(localized: "A folder could not be renamed")
        failure? += "\n" + FailureMessage.text(for: stopped.error, locale: .current)
    }

    /// Show in …: the folder that holds both names, in the folder view.
    private func show(_ parent: FileItem.ID) {
        dismiss()
        Task { await browser.navigate(pane: browser.layout.focusedPaneIndex, to: parent) }
    }
}

/// The sheet's name, years and templates, following the model.
private struct RenameInAllYearsForm: View {
    @Bindable var model: RenameInAllYearsModel
    let show: (FileItem.ID) -> Void

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "New name"), text: $model.newName)
                    .accessibilityIdentifier("renameInAllYearsName")
            }
            Section {
                ForEach(model.plan.entries, id: \.place.folder, content: row)
            }
            if !model.templates.isEmpty {
                Section {
                    ForEach(model.templates) { template in
                        Toggle(template.name, isOn: corrects(template))
                    }
                } header: {
                    Text("Also Correct the Templates")
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: OneFolderName.Entry) -> some View {
        let label = model.label(of: entry.place)
        if model.trimmedName == model.oldName {
            LabeledContent(label, value: entry.place.name)
        } else {
            switch entry.outcome {
            case .renamed:
                Toggle(isOn: renames(entry.place.folder)) {
                    LabeledContent(label, value: "\(entry.place.name) → \(model.trimmedName)")
                }
            case .alreadyNamed:
                LabeledContent(
                    label, value: "\(entry.place.name)  " + String(localized: "already named so")
                )
                .foregroundStyle(.secondary)
            case .besideFolderNamed(let other):
                VStack(alignment: .leading) {
                    LabeledContent(label, value: entry.place.name)
                    Text("\(label) already has a folder “\(other)”")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Show in \(label)") { show(entry.place.parent) }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private func renames(_ folder: FileItem.ID) -> Binding<Bool> {
        Binding(
            get: { !model.excluded.contains(folder) },
            set: { if $0 { model.excluded.remove(folder) } else { model.excluded.insert(folder) } })
    }

    private func corrects(_ template: FolderTemplate) -> Binding<Bool> {
        Binding(
            get: { !model.uncorrected.contains(template.id) },
            set: {
                if $0 {
                    model.uncorrected.remove(template.id)
                } else {
                    model.uncorrected.insert(template.id)
                }
            })
    }
}
