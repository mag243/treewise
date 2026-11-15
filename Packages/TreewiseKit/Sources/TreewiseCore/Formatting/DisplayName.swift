import Foundation

/// The name the list and the icon view show for an item (ADR 0023, ADR 0109). Sorting,
/// search and rename always use the full name.
public enum DisplayName {
    /// Returns the item's name, without its extension (ADR 0109) when `showsExtension` is
    /// off. Folders, volumes and names that start with a dot stay whole.
    public static func text(for item: FileItem, showsExtension: Bool) -> String {
        showsExtension ? item.name : FileName.stem(of: item.name, kind: item.kind)
    }
}
