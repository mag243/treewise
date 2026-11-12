import AppKit

/// A field a file's name is typed in: the list's and the icon view's.
@MainActor
protocol NameFieldEditing: NSTextFieldDelegate {}

/// Underlining the misspelled words of a name while it is typed, when the user turned
/// on Check Spelling While Typing (ADR 0084). A window's text fields share one field
/// editor, so it checks while a name is typed and stops when the name is done, and the
/// address bar and the search field are never checked.
@MainActor
enum NameSpelling {
    /// Starts or stops checking the name being typed in `field`.
    static func check(_ field: NSTextField, _ checks: Bool) {
        (field.currentEditor() as? NSTextView)?.isContinuousSpellCheckingEnabled = checks
    }

    /// Stops checking, as the name the field editor of `notification` typed is done.
    static func stop(after notification: Notification) {
        let editor = notification.userInfo?["NSFieldEditor"] as? NSTextView
        editor?.isContinuousSpellCheckingEnabled = false
    }

    /// Follows the setting in the name being typed in `window`, if one is.
    static func update(in window: NSWindow?, checks: Bool) {
        guard let editor = window?.firstResponder as? NSTextView, editor.isFieldEditor,
            let field = editor.delegate as? NSTextField, field.delegate is NameFieldEditing
        else { return }
        editor.isContinuousSpellCheckingEnabled = checks
    }
}
