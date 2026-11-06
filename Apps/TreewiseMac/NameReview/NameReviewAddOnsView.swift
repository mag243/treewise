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
    @State private var editing: String?
    @State private var draft = ""
    @State private var insertion: PatternInsertion?

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
            .disabled(module.isOn && model.modules.filter(\.isOn).count == 1)
            .frame(minWidth: 130, alignment: .leading)
            Text(Self.colored(module.templateText)).font(.caption.monospaced()).lineLimit(1)
                .opacity(module.isOn ? 1 : 0.5)
            Text(NameReviewText.origin(of: module)).font(.caption)
                .foregroundStyle(module.origin == .user ? Color.accentColor : .secondary)
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

    @ViewBuilder
    private func links(for module: NameReviewModule) -> some View {
        if module.isOn, module.origin == .notRecognized, editing != module.id {
            Button("Use Your Default: \(model.defaultPattern)") {
                Task { await model.useDefaultPattern(module.id) }
            }
            .buttonStyle(.link).font(.caption)
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
                    module.id == NameModuleDescription.defaultModuleID
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
            text[range].backgroundColor = Color(nsColor: FieldColors.color(mark.colorIndex))
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
