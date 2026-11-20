import Foundation

/// What a synced record is about (ADR 0144): a folder's settings by the folder's path from
/// its drive's root, the saved patterns as one list, or a folder template by its id.
public enum SyncKey: Hashable, Sendable {
    /// A folder's settings; the path from the drive's root, its parts joined by `/`.
    case folder(String)
    /// The saved patterns, as one list with its order and its default (ADR 0068).
    case savedPatterns
    /// A folder template, by its id (ADR 0141).
    case template(String)

    private static let folderKind = "folder"
    private static let savedPatternsKind = "savedPatterns"
    private static let templateKind = "template"
    private static let separator: Character = "/"

    /// The key as it is written in a device's file: its kind, a `/`, and its path or id.
    public var text: String {
        switch self {
        case .folder(let path): "\(Self.folderKind)\(Self.separator)\(path)"
        case .savedPatterns: Self.savedPatternsKind
        case .template(let id): "\(Self.templateKind)\(Self.separator)\(id)"
        }
    }

    /// The key written as `text`, or nil for a kind this version does not know, which a
    /// newer Treewise may write.
    public init?(text: String) {
        if text == Self.savedPatternsKind {
            self = .savedPatterns
            return
        }
        guard let split = text.firstIndex(of: Self.separator) else { return nil }
        let rest = String(text[text.index(after: split)...])
        switch text[..<split] {
        case Self.folderKind: self = .folder(rest)
        case Self.templateKind: self = .template(rest)
        default: return nil
        }
    }
}
