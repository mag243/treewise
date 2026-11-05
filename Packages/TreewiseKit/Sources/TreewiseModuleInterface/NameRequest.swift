import Foundation

/// What a module receives about one item the user chose (ADR 0057). It holds data
/// only: no path, and nothing that leads to the item or its folder.
public struct NameRequest: Hashable, Sendable, Codable {
    /// An id for this request. It means nothing outside it.
    public let id: String
    /// The item's name.
    public let name: String
    /// The item's type, as a uniform type identifier.
    public let contentType: String
    /// The item's size in bytes, when known.
    public let byteCount: Int64?
    /// When the item was created, when known.
    public let created: Date?
    /// When the item was last changed, when known.
    public let modified: Date?
    /// The names of the other items in its folder, for recognizing a pattern.
    public let siblingNames: [String]
    /// The content the module declared, as far as it could be extracted.
    public let content: ModuleContent

    /// Creates a request.
    public init(
        id: String, name: String, contentType: String, byteCount: Int64?, created: Date?,
        modified: Date?, siblingNames: [String], content: ModuleContent
    ) {
        self.id = id
        self.name = name
        self.contentType = contentType
        self.byteCount = byteCount
        self.created = created
        self.modified = modified
        self.siblingNames = siblingNames
        self.content = content
    }
}
