import Foundation
import TreewiseCore
import UniformTypeIdentifiers

/// The system's icon for a file's type, as Files shows it, made once per type and size and
/// kept for every file of the type (ADR 0148). The app gives the maker, Quick Look on the
/// iPad; a type asked for while its icon is made waits for that one request, and a name
/// without a type gets none, so its row keeps its symbol.
@MainActor
public final class TypeIconCache<Icon: AnyObject & Sendable> {
    /// Makes the icon for a file of the item's type at a size in points, or nil.
    public typealias Make = @Sendable (FileItem, Int) async -> Icon?

    private let make: Make
    private var icons: [String: Icon] = [:]
    private var making: [String: Task<Icon?, Never>] = [:]

    /// Creates a cache that makes its icons with `make`.
    public init(make: @escaping Make) {
        self.make = make
    }

    /// The icon made earlier for files of the item's type at `size`, if any.
    public func cachedIcon(for item: FileItem, size: Int) -> Icon? {
        key(of: item, size: size).flatMap { icons[$0] }
    }

    /// The icon for files of the item's type at `size`, made the first time it is asked for;
    /// nil when the name has no type or no icon could be made.
    public func icon(for item: FileItem, size: Int) async -> Icon? {
        guard let key = key(of: item, size: size) else { return nil }
        if let icon = icons[key] { return icon }
        if let task = making[key] { return await task.value }
        let make = make
        let task = Task { await make(item, size) }
        making[key] = task
        let icon = await task.value
        making[key] = nil
        if let icon { icons[key] = icon }
        return icon
    }

    /// The type's identifier and the size, or nil for a name whose extension is no type.
    private func key(of item: FileItem, size: Int) -> String? {
        let pathExtension = (item.name as NSString).pathExtension
        guard !pathExtension.isEmpty,
            let type = UTType(filenameExtension: pathExtension.lowercased())
        else { return nil }
        return "\(type.identifier) \(size)"
    }
}
