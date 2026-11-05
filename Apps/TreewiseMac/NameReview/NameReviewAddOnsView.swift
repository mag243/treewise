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
                if isOpen, model.trustsDatesInFiles {
                    Text("PDF dates: trusted").font(.caption).foregroundStyle(.secondary)
                    Button("Undo") { Task { await model.setTrustsDatesInFiles(false) } }
                        .buttonStyle(.link).font(.caption)
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
            Toggle(
                NameReviewText.name(of: module),
                isOn: Binding(
                    get: { module.isOn },
                    set: { isOn in Task { await model.setModule(module.id, on: isOn) } })
            )
            .toggleStyle(.checkbox)
            .disabled(module.isOn && model.modules.filter(\.isOn).count == 1)
            .frame(minWidth: 130, alignment: .leading)
            Text(module.templateText).font(.caption.monospaced()).lineLimit(1).opacity(
                module.isOn ? 1 : 0.5)
            Text(NameReviewText.origin(of: module)).font(.caption)
                .foregroundStyle(module.origin == .user ? Color.accentColor : .secondary)
            if module.isOn, editing != module.id {
                Button("Change") {
                    draft = module.templateText
                    editing = module.id
                }
                .buttonStyle(.link).font(.caption)
            }
        }
        if editing == module.id { editor(for: module) }
    }

    private func editor(for module: NameReviewModule) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Pattern", text: $draft)
                .font(.caption.monospaced())
                .onChange(of: draft) { _, text in
                    Task { await model.setTemplate(module.id, to: text) }
                }
                .onSubmit(finish)
            HStack(spacing: 5) {
                ForEach(module.description.fields + [.folder], id: \.name) { field in
                    Button("{\(field.name)}") { draft = (draft + " " + token(field)).trimmed }
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

    private func token(_ field: NameTemplate.Field) -> String {
        field.kind == .date ? "{\(field.name):yyyy.MM.dd}" : "{\(field.name)}"
    }

    private func finish() {
        if !mustStayOpen { editing = nil }
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespaces) }
}
