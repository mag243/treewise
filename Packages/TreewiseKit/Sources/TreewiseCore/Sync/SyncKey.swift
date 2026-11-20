import Foundation

/// What synced records are about (ADR 0144): a folder's settings, a saved pattern, the list
/// of saved patterns, a folder template, or one folder in a template's tree.
public enum SyncElement: Hashable, Sendable {
    /// A folder's settings, by its path from the drive's root, its parts joined by `/`.
    case folder(String)
    /// A saved pattern, by its id (ADR 0068).
    case pattern(String)
    /// The saved patterns as a list: which one is the default.
    case patternList
    /// A folder template, by its id (ADR 0141).
    case template(String)
    /// A folder in a template's tree, by the template's id and the folder's.
    case templateFolder(template: String, folder: String)
}

/// One part of an element, merged on its own (ADR 0144).
public struct SyncKey: Hashable, Sendable {
    /// The part that says whether the element is there; false when it was removed.
    public static let exists = "exists"

    /// The element.
    public let element: SyncElement
    /// The part's name, as the element's codec names it.
    public let part: String

    /// The part `part` of `element`.
    public init(_ element: SyncElement, _ part: String) {
        self.element = element
        self.part = part
    }

    /// The `exists` part of `element`.
    public static func exists(_ element: SyncElement) -> SyncKey {
        SyncKey(element, exists)
    }

    /// A text that orders keys alike on every device.
    public var order: String {
        "\(element.kind)\u{0}\(element.ids.joined(separator: "\u{0}"))\u{0}\(part)"
    }
}

extension SyncElement {
    /// Why an element is not read.
    public enum Problem: Error, Equatable {
        case unknownKind(String)
    }

    var kind: String {
        switch self {
        case .folder: "folder"
        case .pattern: "pattern"
        case .patternList: "patternList"
        case .template: "template"
        case .templateFolder: "templateFolder"
        }
    }

    var ids: [String] {
        switch self {
        case .folder(let path): [path]
        case .pattern(let id), .template(let id): [id]
        case .patternList: []
        case .templateFolder(let template, let folder): [template, folder]
        }
    }
}

extension SyncElement: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, path, id, template, folder
    }

    /// Reads an element; one of a kind this version does not know throws `unknownKind`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "folder": self = .folder(try container.decode(String.self, forKey: .path))
        case "pattern": self = .pattern(try container.decode(String.self, forKey: .id))
        case "patternList": self = .patternList
        case "template": self = .template(try container.decode(String.self, forKey: .id))
        case "templateFolder":
            self = .templateFolder(
                template: try container.decode(String.self, forKey: .template),
                folder: try container.decode(String.self, forKey: .folder))
        default: throw Problem.unknownKind(kind)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .folder(let path): try container.encode(path, forKey: .path)
        case .pattern(let id), .template(let id): try container.encode(id, forKey: .id)
        case .patternList: break
        case .templateFolder(let template, let folder):
            try container.encode(template, forKey: .template)
            try container.encode(folder, forKey: .folder)
        }
    }
}
