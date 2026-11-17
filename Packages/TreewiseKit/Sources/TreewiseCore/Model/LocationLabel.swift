import Foundation

/// The rules for a location's own name (ADR 0119): when the name iOS gives a folder
/// says nothing to the user, and what a name the user types leaves.
public enum LocationLabel {
    /// Whether `name` is a machine-made name, such as the UUID iOS gives the folder of
    /// a File Provider app like Dropbox, which Treewise asks the user to replace.
    public static func isMachineMade(_ name: String) -> Bool {
        UUID(uuidString: name) != nil
    }

    /// A label as typed, without spaces around it; `nil` when nothing is left, as the
    /// location then keeps its own name.
    public static func cleaned(_ label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
