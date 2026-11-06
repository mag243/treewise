import Foundation
import TreewiseCore

/// What a module receives about one item the user chose (ADR 0057). It holds data
/// only: no path, and nothing that leads to the item or its folder. The folder's name
/// is a name, as the value of `{folder}` is (ADR 0067).
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
    /// The date the file itself suggests, with its source, when it has one.
    public let suggestedDate: SuggestedDate?
    /// The names of the other items in its folder, for recognizing a pattern.
    public let siblingNames: [String]
    /// The content the module declared, as far as it could be extracted.
    public let content: ModuleContent
    /// The name of the item's folder.
    public var folderName: String
    /// The folder's pattern for this module, which it may follow, or nil when it has none.
    public var pattern: String?

    /// Creates a request.
    public init(
        id: String, name: String, contentType: String, byteCount: Int64?, created: Date?,
        modified: Date?, suggestedDate: SuggestedDate? = nil, siblingNames: [String],
        content: ModuleContent, folderName: String = "", pattern: String? = nil
    ) {
        self.id = id
        self.name = name
        self.contentType = contentType
        self.byteCount = byteCount
        self.created = created
        self.modified = modified
        self.suggestedDate = suggestedDate
        self.siblingNames = siblingNames
        self.content = content
        self.folderName = folderName
        self.pattern = pattern
    }
}
