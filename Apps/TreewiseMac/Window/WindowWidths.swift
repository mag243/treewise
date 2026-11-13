import CoreGraphics
import TreewiseUI

/// The widths that keep the window's rows whole (ADR 0037, ADR 0093): the sidebar's
/// range, the folder side's least width, which fits the command bar with its icons only,
/// and the narrowest window, which the sidebar gives way to first.
enum WindowWidths {
    static let sidebarMinimum = CGFloat(SidebarWidth.minimum)
    static let sidebarMaximum = CGFloat(SidebarWidth.maximum)
    static let folderMinimum = CGFloat(SidebarWidth.folderMinimum)
    static let windowMinimum = CGFloat(SidebarWidth.narrowestWindow)
}
