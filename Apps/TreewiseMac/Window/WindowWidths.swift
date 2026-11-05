import CoreGraphics

/// The widths that keep the window's rows whole (ADR 0037): the sidebar's
/// range, and the narrowest window that still fits the command bar with its
/// icons only.
enum WindowWidths {
    static let sidebarMinimum: CGFloat = 160
    static let sidebarIdeal: CGFloat = 200
    static let sidebarMaximum: CGFloat = 240
    /// The command bar with its icons only, over the folder side.
    private static let folderMinimum: CGFloat = 380

    /// The narrowest window: the widest sidebar beside the folder's minimum.
    static let windowMinimum: CGFloat = sidebarMaximum + folderMinimum
}
