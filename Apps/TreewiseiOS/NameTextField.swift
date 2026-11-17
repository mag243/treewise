import SwiftUI
import TreewiseUI
import UIKit

/// A name or pattern being typed, in a UIKit field (ADR 0130): its parts coloured as on
/// the Mac, also while it is edited; it takes ⌥Esc and F5 for proposals and ↑ and ↓ to move
/// through them, as the Mac's rename does, and gives Return to `onSubmit`.
struct NameTextField: UIViewRepresentable {
    /// What a key asks of the view holding the field.
    enum Key {
        case suggest
        case previous
        case next
    }

    /// How the field looks and starts.
    struct Style {
        var font = UIFont.preferredFont(forTextStyle: .body)
        var textColor = UIColor.label
        var placeholder = ""
        var isStruckThrough = false
        /// Whether the field takes the keyboard when it shows, as a sheet's field does.
        var focusesOnAppear = false
        /// Whether the field selects the name without its extension when it first starts,
        /// as a rename does; else the whole text.
        var selectsBaseName = false
        /// The UI tests' name for the field.
        var identifier = "name"
    }

    @Binding var text: String
    var marks: [NameMark] = []
    var style = Style()
    var isEnabled = true
    var onKey: (Key) -> Void = { _ in }
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> KeyedTextField {
        let field = KeyedTextField()
        field.adjustsFontForContentSizeCategory = true
        field.clearButtonMode = .whileEditing
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .done
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if style.focusesOnAppear {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        }
        return field
    }

    func updateUIView(_ field: KeyedTextField, context: Context) {
        context.coordinator.parent = self
        field.onKey = onKey
        field.isEnabled = isEnabled
        field.placeholder = style.placeholder
        field.accessibilityIdentifier = style.identifier
        field.typingAttributes = [.font: style.font, .foregroundColor: style.textColor]
        let shown = NameMarkColors.attributed(
            text, marks: marks, font: style.font, textColor: style.textColor,
            isStruckThrough: style.isStruckThrough)
        guard field.attributedText != shown else { return }
        // Colouring the text the user types keeps the caret where it is; a text put in from
        // outside, such as a proposal taken, has the caret after it.
        let isSameText = field.text == text
        let selection = field.selectedTextRange
        field.attributedText = shown
        if field.isFirstResponder {
            field.selectedTextRange =
                isSameText
                ? selection
                : field.textRange(from: field.endOfDocument, to: field.endOfDocument)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NameTextField
        private var hasSelected = false

        init(parent: NameTextField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            guard parent.style.focusesOnAppear, !hasSelected else { return }
            hasSelected = true
            let text = field.text ?? ""
            let length =
                parent.style.selectsBaseName
                ? (text as NSString).deletingPathExtension.utf16.count : text.utf16.count
            // The field selects only once it shows, so the selection follows a turn.
            DispatchQueue.main.async {
                guard let end = field.position(from: field.beginningOfDocument, offset: length)
                else { return }
                field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: end)
            }
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            field.resignFirstResponder()
            return false
        }
    }
}

/// A text field that answers the rename's keys.
final class KeyedTextField: UITextField {
    var onKey: ((NameTextField.Key) -> Void)?

    override var keyCommands: [UIKeyCommand]? {
        let commands = [
            UIKeyCommand(
                input: UIKeyCommand.inputEscape, modifierFlags: .alternate,
                action: #selector(suggest)),
            UIKeyCommand(input: UIKeyCommand.f5, modifierFlags: [], action: #selector(suggest)),
            UIKeyCommand(
                input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(up)),
            UIKeyCommand(
                input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(down)),
        ]
        for command in commands { command.wantsPriorityOverSystemBehavior = true }
        return commands
    }

    @objc private func suggest() { onKey?(.suggest) }
    @objc private func up() { onKey?(.previous) }
    @objc private func down() { onKey?(.next) }
}
