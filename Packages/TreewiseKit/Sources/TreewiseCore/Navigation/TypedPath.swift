import Foundation

/// A path typed in the address bar (M5b): where it points and how its last
/// folder name completes. Paths are POSIX paths; whether a folder is there
/// and inside the boundary (ADR 0019) is for the caller to check.
public enum TypedPath {
    private static let separator: Character = "/"
    private static let homePrefix = "~"

    /// The absolute path `text` names, or `nil` when it names none.
    ///
    /// Spaces around it are ignored; `~` and `~/…` start at `home`; a path
    /// that starts with neither `/` nor `~` is relative to `current`; `.` and
    /// `..` are resolved, never above `/`; repeated and trailing slashes go.
    /// `~user` is not supported and names nothing.
    public static func resolve(_ text: String, home: String, current: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let absolute: String
        if trimmed == homePrefix || trimmed.hasPrefix(homePrefix + String(separator)) {
            absolute = home + trimmed.dropFirst(homePrefix.count)
        } else if trimmed.hasPrefix(homePrefix) {
            return nil
        } else if trimmed.first == separator {
            absolute = trimmed
        } else {
            absolute = current + String(separator) + trimmed
        }
        return standardized(absolute)
    }

    /// What `text` completes to: for each folder name in the folder its last
    /// slash points at that starts with what follows the slash, ignoring case
    /// and diacritics, `text` with that name in place of the partial one.
    /// Sorted as Finder sorts names; empty when there is nothing to look in.
    /// `subfolders` gives the names of the folders inside an absolute path.
    public static func completions(
        for text: String, home: String, current: String, subfolders: (String) -> [String]
    ) -> [String] {
        guard let folder = completionFolder(for: text, home: home, current: current) else {
            return []
        }
        let slash = text.lastIndex(of: separator)
        let prefix = slash.map { String(text[...$0]) } ?? ""
        let partial = slash.map { String(text[text.index(after: $0)...]) } ?? text
        return subfolders(folder)
            .filter { partial.isEmpty || starts($0, with: partial) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { prefix + $0 }
    }

    /// The absolute path of the folder whose subfolders complete `text`: the
    /// one its last slash points at, or `current` without a slash; `nil` for
    /// an empty text.
    public static func completionFolder(for text: String, home: String, current: String)
        -> String?
    {
        guard !text.isEmpty else { return nil }
        let prefix = text.lastIndex(of: separator).map { String(text[...$0]) } ?? "."
        return resolve(prefix, home: home, current: current)
    }

    private static func starts(_ name: String, with partial: String) -> Bool {
        name.range(of: partial, options: [.caseInsensitive, .diacriticInsensitive, .anchored])
            != nil
    }

    /// `path` with `.` and `..` resolved and without empty components.
    private static func standardized(_ path: String) -> String {
        var components: [Substring] = []
        for component in path.split(separator: separator) {
            switch component {
            case ".": continue
            case "..": _ = components.popLast()
            default: components.append(component)
            }
        }
        return String(separator) + components.joined(separator: String(separator))
    }
}
