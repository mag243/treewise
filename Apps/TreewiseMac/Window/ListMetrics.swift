import AppKit

/// The size of a row's icon and the room between it and the name, alike in the file
/// list, the sidebar and the lists of folders in templates.
enum ListMetrics {
    static let iconSide: CGFloat = 16
    static let iconSize = NSSize(width: iconSide, height: iconSide)
    /// The room between a row's icon and its name.
    static let iconSpacing: CGFloat = 6
}
