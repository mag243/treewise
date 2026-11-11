import AppKit
import TreewiseCore
import TreewiseUI

/// The editor of an add-on's pattern in the overview's header: the pattern's field, a button
/// for each field the add-on and Treewise fill, which lands where the cursor was, the way
/// back to the add-on's own pattern, and Done, kept until the pattern can be read.
@MainActor
final class AddOnPatternEditor: NSStackView {
    private static let indent: CGFloat = 140
    private static let spacing: CGFloat = 4
    private static let buttonSpacing: CGFloat = 5
    private static let fieldWidth: CGFloat = 420

    private let moduleID: String
    private let model: NameReviewModel
    private let pattern: PatternFieldDriver
    private let tokens = NSStackView()
    private let problem = NSTextField(labelWithString: "")
    private lazy var done = ClosureButton(title: String(localized: "Done")) { [weak self] in
        self?.finish()
    }
    private let close: () -> Void

    init(module: NameReviewModule, model: NameReviewModel, close: @escaping () -> Void) {
        moduleID = module.id
        self.model = model
        self.close = close
        pattern = PatternFieldDriver(text: module.templateText)
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = Self.spacing
        edgeInsets = NSEdgeInsets(top: 0, left: Self.indent, bottom: 0, right: 0)
        let id = module.id
        pattern.onChange = { text in Task { await model.setTemplate(id, to: text) } }
        pattern.onSubmit = { [weak self] in self?.finish() }
        pattern.field.setAccessibilityLabel(String(localized: "Pattern"))
        pattern.field.widthAnchor.constraint(equalToConstant: Self.fieldWidth).isActive = true
        done.controlSize = .small
        problem.font = .preferredFont(forTextStyle: .caption1)
        problem.textColor = .systemOrange
        tokens.spacing = Self.buttonSpacing
        addArrangedSubview(pattern.field)
        addArrangedSubview(tokens)
        addArrangedSubview(problem)
        show(module)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Shows what the add-on fills, and the problem of the pattern typed.
    func show(_ module: NameReviewModule) {
        var buttons: [NSView] = []
        for field in module.description.fields + NameTemplate.Field.suppliedByTreewise {
            let token = field.kind == .date ? "{\(field.name):yyyy.MM.dd}" : "{\(field.name)}"
            let button = ClosureButton(title: "{\(field.name)}") { [pattern] in
                pattern.insert(token)
            }
            button.controlSize = .small
            button.font = .monospacedSystemFont(
                ofSize: NSFont.smallSystemFontSize, weight: .regular)
            buttons.append(button)
        }
        let model = model
        let id = module.id
        let reset = LinkButton(
            module.description.takesTheDefaultModulesPart
                ? String(localized: "Recognize Again") : String(localized: "Use Default")
        ) { [weak self] in
            Task {
                await model.resetTemplate(id)
                self?.showDraft(model.modules.first { $0.id == id }?.templateText ?? "")
            }
        }
        tokens.setViews(buttons, in: .leading)
        tokens.setViews([reset, done], in: .trailing)
        done.isEnabled = module.templateProblem == nil
        problem.stringValue = module.templateProblem.map(NameReviewText.text(for:)) ?? ""
        problem.isHidden = module.templateProblem == nil
    }

    /// Puts `text` in the field, as a saved or found pattern was taken.
    func showDraft(_ text: String) {
        pattern.field.stringValue = text
        pattern.field.mark(FieldColors.marks(inPattern: text))
    }

    /// Closes the editor, unless its pattern cannot be read yet.
    private func finish() {
        guard model.modules.first(where: { $0.id == moduleID })?.templateProblem == nil else {
            return
        }
        close()
    }
}
