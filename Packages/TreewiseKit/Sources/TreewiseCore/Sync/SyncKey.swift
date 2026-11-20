import Foundation

/// What a synced record is about (ADR 0144): a folder's settings by the folder's path from
/// its drive's root, a saved pattern or a folder template by its id, or which saved pattern
/// is the default.
public enum SyncKey: Hashable, Sendable {
    /// A folder's settings; the path from the drive's root, its parts joined by `/`.
    case folder(String)
    /// A saved pattern, by its id (ADR 0068).
    case savedPattern(String)
    /// Which saved pattern is the default.
    case defaultPattern
    /// A folder template, by its id (ADR 0141).
    case template(String)

    private static let folderKind = "folder"
    private static let savedPatternKind = "pattern"
    private static let defaultPatternKind = "defaultPattern"
    private static let templateKind = "template"
    private static let separator: Character = "/"

    /// The key as it is written in a device's file: its kind, a `/`, and its path or id.
    public var text: String {
        switch self {
        case .folder(let path): "\(Self.folderKind)\(Self.separator)\(path)"
        case .savedPattern(let id): "\(Self.savedPatternKind)\(Self.separator)\(id)"
        case .defaultPattern: Self.defaultPatternKind
        case .template(let id): "\(Self.templateKind)\(Self.separator)\(id)"
        }
    }

    /// The key written as `text`, or nil for a kind this version does not know, which a
    /// newer Treewise may write.
    public init?(text: String) {
        if text == Self.defaultPatternKind {
            self = .defaultPattern
            return
        }
        guard let split = text.firstIndex(of: Self.separator) else { return nil }
        let rest = String(text[text.index(after: split)...])
        switch text[..<split] {
        case Self.folderKind: self = .folder(rest)
        case Self.savedPatternKind: self = .savedPattern(rest)
        case Self.templateKind: self = .template(rest)
        default: return nil
        }
    }
}
