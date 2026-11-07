import SwiftUI
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI

/// The add-ons and their patterns, which close to one line.
struct NameReviewAddOnsView: View {
    private static let visibleInSummary = 2
    private static let listMaximumHeight: CGFloat = 132

    let model: NameReviewModel
    @Binding var isOpen: Bool
    /// The app's licences, for Enter Licence Key… (ADR 0071).
    let licences: LicenceKeeper?
    @State private var entersKey = false
    @State private var editing: String?
    @State private var draft = ""
    @State private var insertion: PatternInsertion?
    /// The add-on whose pattern is being saved, while its name is asked (ADR 0068).
    @State private var savingFor: String?
    @State private var savedName = ""
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    isOpen.toggle()
                    if !isOpen { editing = nil }
                } label: {
                    Label(title, systemImage: isOpen ? "chevron.down" : "chevron.right")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .disabled(isOpen && mustStayOpen)
                Spacer()
                if model.readingCount > 0 {
                    ProgressView().controlSize(.small)
                    Text("Reading \(model.readingCount) files…").font(.caption).foregroundStyle(
                        .secondary)
                }
            }
            if isOpen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(model.modules) { row(for: $0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: Self.listMaximumHeight)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .licenceKeyEntry(
            isPresented: $entersKey, keeper: licences, host: NameReviewWindow.host,
            onUnlocked: { Task { await model.start() } }
        )
        .alert("Save Pattern", isPresented: isSaving) {
            TextField("Name", text: $savedName)
            Button("Save") {
                if let savingFor { _ = model.savePattern(of: savingFor, as: savedName) }
                savingFor = nil
            }
            .disabled(savedName.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Cancel", role: .cancel) { savingFor = nil }
        } message: {
            Text("The pattern is kept under this name, to pick in other folders.")
        }
    }

    private var isSaving: Binding<Bool> {
        Binding(get: { savingFor != nil }, set: { if !$0 { savingFor = nil } })
    }

    /// The menu of saved patterns for an add-on, as an icon or under a title.
    private func savedPatterns(for module: NameReviewModule, title: String? = nil) -> some View {
        SavedPatternsMenu(
            title: title,
            choices: { model.savedPatternChoices(for: module.id) },
            found: {
                let now = model.modules.first { $0.id == module.id }
                return (now?.candidates ?? [], now?.templateText ?? "")
            },
            use: { id in
                Task {
                    await model.useSavedPattern(id, for: module.id)
                    if editing == module.id {
                        draft = model.modules.first { $0.id == module.id }?.templateText ?? draft
                    }
                }
            },
            useFound: { text in
                Task {
                    await model.useFoundPattern(text, for: module.id)
                    if editing == module.id { draft = text }
                }
            },
            toUpdate: { model.savedPatternToUpdate(for: module.id)?.name },
            update: { Task { await model.updateSavedPattern(for: module.id) } },
            save: {
                savedName = ""
                savingFor = module.id
            },
            edit: { openSettings() }
        )
        .fixedSize()
    }

    private var mustStayOpen: Bool {
        guard let editing else { return false }
        return model.modules.first { $0.id == editing }?.templateProblem != nil
    }

    private var title: String {
        guard !isOpen else { return String(localized: "Add-ons and their patterns") }
        let on = model.modules.filter(\.isOn)
        var names = on.prefix(Self.visibleInSummary).map { module in
            module.origin == .user
                ? "\(NameReviewText.name(of: module)) •" : NameReviewText.name(of: module)
        }.joined(separator: ", ")
        if on.count > Self.visibleInSummary { names += " +\(on.count - Self.visibleInSummary)" }
        return String(localized: "Add-ons: \(names)")
    }

    @ViewBuilder
    private func row(for module: NameReviewModule) -> some View {
        HStack(spacing: 10) {
            if model.modules.count > 1 {
                // The grip moves the add-on: the first one gives the first name (ADR 0065).
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                    .help("Drag to change the order of the add-ons")
                    .draggable(module.id)
            }
            Toggle(
                NameReviewText.name(of: module),
                isOn: Binding(
                    get: { module.isOn },
                    set: { isOn in Task { await model.setModule(module.id, on: isOn) } })
            )
            .toggleStyle(.checkbox)
            // One without a licence cannot be turned on (ADR 0071).
            .disabled(
                module.licence == .unlicensed
                    || (module.isOn && model.modules.filter(\.isOn).count == 1)
            )
            .frame(minWidth: 130, alignment: .leading)
            Text(Self.colored(module.templateText)).font(.caption.monospaced()).lineLimit(1)
                .opacity(module.isOn ? 1 : 0.5)
            Text(NameReviewText.origin(of: module)).font(.caption)
                .foregroundStyle(module.origin == .user ? Color.accentColor : .secondary)
            licence(of: module)
            links(for: module)
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, id != module.id,
                let place = model.modules.firstIndex(where: { $0.id == module.id })
            else { return false }
            Task { await model.moveModule(id, to: place) }
            return true
        }
        .accessibilityAction(named: Text("Move Up")) { move(module, by: -1) }
        .accessibilityAction(named: Text("Move Down")) { move(module, by: 1) }
        if editing == module.id { editor(for: module) }
    }

    /// The licence of a paid add-on: quiet in its trial, a lock and the way to a licence
    /// when it needs one, nothing when licensed (ADR 0071).
    @ViewBuilder
    private func licence(of module: NameReviewModule) -> some View {
        switch module.licence {
        case .trial(let days):
            Text(LicenceText.state(.trial(daysLeft: days))).font(.caption).foregroundStyle(
                .secondary)
        case .unlicensed:
            Label(LicenceText.state(.unlicensed), systemImage: "lock.fill")
                .font(.caption).foregroundStyle(.orange)
            if module.description.purchaseURL != nil {
                Button("Buy…") { LicenceText.buy(module.description) }
                    .buttonStyle(.link).font(.caption)
            }
            Button("Enter Licence Key…") { entersKey = true }
                .buttonStyle(.link).font(.caption)
        case .licensed, nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func links(for module: NameReviewModule) -> some View {
        if module.isOn, module.origin == .notRecognized, editing != module.id {
            Button("Use Your Default: \(model.defaultPattern)") {
                Task { await model.useDefaultPattern(module.id) }
            }
            .buttonStyle(.link).font(.caption)
            savedPatterns(for: module, title: String(localized: "Choose a Saved Pattern"))
        } else if module.isOn {
            savedPatterns(for: module)
        }
        if module.isOn, editing != module.id {
            Button("Change") {
                draft = module.templateText
                editing = module.id
            }
            .buttonStyle(.link).font(.caption)
        }
    }

    private func move(_ module: NameReviewModule, by offset: Int) {
        guard let place = model.modules.firstIndex(where: { $0.id == module.id }) else { return }
        Task { await model.moveModule(module.id, to: place + offset) }
    }

    private func editor(for module: NameReviewModule) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            PatternField(text: $draft, insertion: insertion, onSubmit: finish)
                .frame(height: 20)
                .onChange(of: draft) { _, text in
                    Task { await model.setTemplate(module.id, to: text) }
                }
            HStack(spacing: 5) {
                ForEach(
                    module.description.fields + NameTemplate.Field.suppliedByTreewise, id: \.name
                ) { field in
                    Button("{\(field.name)}") { insertion = PatternInsertion(token: token(field)) }
                        .font(.caption.monospaced()).controlSize(.small)
                }
                Spacer()
                Button(
                    module.description.takesTheDefaultModulesPart
                        ? "Recognize Again" : "Use Default"
                ) {
                    Task {
                        await model.resetTemplate(module.id)
                        draft = model.modules.first { $0.id == module.id }?.templateText ?? draft
                    }
                }
                .buttonStyle(.link).font(.caption)
                Button("Done", action: finish).controlSize(.small).disabled(
                    module.templateProblem != nil)
            }
            if let problem = module.templateProblem {
                Label(NameReviewText.text(for: problem), systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(.leading, 140)
    }

    /// A pattern with each field in its colour, as the name it made shows them.
    private static func colored(_ pattern: String) -> AttributedString {
        var text = AttributedString(pattern)
        for mark in FieldColors.marks(inPattern: pattern) {
            guard let range = Range(mark.range, in: text) else { continue }
            text[range].backgroundColor = Color(nsColor: mark.color)
        }
        return text
    }

    private func token(_ field: NameTemplate.Field) -> String {
        field.kind == .date ? "{\(field.name):yyyy.MM.dd}" : "{\(field.name)}"
    }

    private func finish() {
        if !mustStayOpen { editing = nil }
    }
}
