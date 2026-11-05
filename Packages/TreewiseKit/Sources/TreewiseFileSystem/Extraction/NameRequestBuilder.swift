import Foundation
import TreewiseCore
import TreewiseModuleInterface

/// Builds what a module receives about an item the user chose (ADR 0057). This is
/// where a path stops: the request holds names and data, never where the item is.
public struct NameRequestBuilder: Sendable {
    /// The most sibling names in a request, enough to recognize a pattern.
    public static let maximumSiblings = 1000
    /// The type reported when the file's own cannot be read.
    private static let unknownContentType = "public.data"

    private let extractor: ContentExtractor
    private let dateReader: FileDateReader

    /// Creates a builder.
    public init(
        extractor: ContentExtractor = ContentExtractor(),
        dateReader: FileDateReader = FileDateReader()
    ) {
        self.extractor = extractor
        self.dateReader = dateReader
    }

    /// Returns the request for an item. Content is read only from a regular file on
    /// this device: a file that is only online would start downloading.
    ///
    /// - Parameters:
    ///   - item: An item the user chose.
    ///   - siblings: The items of its folder. Hidden items and the item itself are left out.
    ///   - neededContent: What the module declared.
    ///   - id: An id that means nothing outside this request.
    public func request(
        for item: FileItem, siblings: [FileItem], neededContent: Set<ModuleContentKind>,
        id: String = UUID().uuidString
    ) -> NameRequest {
        let url = URL(fileURLWithPath: item.id.rawValue)
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .creationDateKey])
        let readable = item.kind == .file && !item.isOnlyOnline
        return NameRequest(
            id: id, name: item.name,
            contentType: values?.contentType?.identifier ?? Self.unknownContentType,
            byteCount: item.size, created: values?.creationDate, modified: item.modified,
            suggestedDate: item.kind == .file
                ? dateReader.suggestedDate(of: url, isOnlyOnline: item.isOnlyOnline) : nil,
            siblingNames: Array(
                siblings.lazy.filter { $0.id != item.id && !$0.isHidden }.map(\.name)
                    .prefix(Self.maximumSiblings)),
            content: readable ? extractor.content(of: url, kinds: neededContent) : ModuleContent())
    }
}
