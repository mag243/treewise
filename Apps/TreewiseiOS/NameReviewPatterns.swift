import SwiftUI
import TreewiseCore
import TreewiseUI

/// The patterns the name overview proposes with (ADR 0129), one block for each add-on it
/// offers, as the Mac's add-on blocks: where the pattern comes from, the pattern itself to
/// type over, and the patterns to take instead.
struct NameReviewPatterns: View {
    let model: NameReviewModel

    var body: some View {
        ForEach(model.modules) { module in
            PatternBlock(model: model, module: module)
        }
    }
}

/// One add-on's pattern.
private struct PatternBlock: View {
    let model: NameReviewModel
    let module: NameReviewModule
    /// The pattern as typed, until it is used.
    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(NameReviewText.name(of: module)).font(.headline)
                Text(NameReviewText.origin(of: module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            NameTextField(
                text: $typed, marks: NameMark.inPattern(typed),
                style: .init(
                    font: .monospacedSystemFont(
                        ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                        weight: .regular),
                    placeholder: String(localized: "Pattern"), identifier: "pattern"),
                onSubmit: { Task { await model.setTemplate(module.id, to: typed) } })
            if let problem = module.templateProblem {
                Text(NameReviewText.text(for: problem)).font(.caption).foregroundStyle(.red)
            }
            choices
        }
        .padding(.vertical, 4)
        .onChange(of: module.templateText, initial: true) { typed = module.templateText }
    }

    private var choices: some View {
        HStack(spacing: 16) {
            if module.origin == .notRecognized {
                Button("Use Your Default: \(model.defaultPattern)") {
                    Task { await model.useDefaultPattern(module.id) }
                }
            }
            let saved = model.savedPatternChoices(for: module.id)
            if !saved.isEmpty || !module.candidates.isEmpty {
                Menu("Choose a Saved Pattern") {
                    if !module.candidates.isEmpty {
                        Section("Found in This Folder") {
                            ForEach(module.candidates, id: \.text) { candidate in
                                Button {
                                    Task {
                                        await model.useFoundPattern(candidate.text, for: module.id)
                                    }
                                } label: {
                                    current(candidate.text, module.templateText == candidate.text)
                                }
                            }
                        }
                    }
                    Section("Saved") {
                        ForEach(saved) { choice in
                            Button {
                                Task { await model.useSavedPattern(choice.id, for: module.id) }
                            } label: {
                                current(choice.pattern.name, choice.isCurrent)
                            }
                            .disabled(choice.problem != nil)
                        }
                    }
                }
            }
        }
        .font(.callout)
        .buttonStyle(.borderless)
    }

    /// A menu item, ticked when it is the pattern in force.
    @ViewBuilder private func current(_ title: String, _ isCurrent: Bool) -> some View {
        if isCurrent {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
