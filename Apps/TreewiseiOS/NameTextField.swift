import SwiftUI
import UIKit

/// A name being typed, in a UIKit field (ADR 0130): it takes ⌥Esc and F5 for proposals and
/// ↑ and ↓ to move through them, as the Mac's rename does, selects the name without its
/// extension when it starts, and gives Return to `onSubmit`.
struct NameTextField: UIViewRepresentable {
    /// What a key asks of the sheet holding the field.
    enum Key {
        case suggest
        case previous
        case next
    }

    @Binding var text: String
    /// Whether the field selects the name without its extension when it starts, as a
    /// rename does; a new folder's name is selected whole.
    var selectsBaseName = true
    let onKey: (Key) -> Void
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> KeyedTextField {
        let field = KeyedTextField()
        field.text = text
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.clearButtonMode = .whileEditing
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        // The UI tests find it by it.
        field.accessibilityIdentifier = "name"
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: KeyedTextField, context: Context) {
        context.coordinator.parent = self
        field.onKey = onKey
        if field.text != text { field.text = text }
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
            guard !hasSelected else { return }
            hasSelected = true
            let text = field.text ?? ""
            let length =
                parent.selectsBaseName
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
