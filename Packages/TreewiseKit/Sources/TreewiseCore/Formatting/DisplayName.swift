import Foundation

/// The name the list and the icon view show for an item (ADR 0023). Sorting,
/// search and rename always use the full name.
public enum DisplayName {
    /// Returns the item's name, without its last extension when
    /// `showsExtension` is off and the item is a file or a package. Folders,
    /// volumes and names that start with a dot stay whole.
    public static func text(for item: FileItem, showsExtension: Bool) -> String {
        guard !showsExtension, item.kind == .file || item.kind == .package,
            !item.name.hasPrefix("."), let dot = item.name.lastIndex(of: "."),
            dot != item.name.startIndex
        else { return item.name }
        return String(item.name[..<dot])
    }
}
