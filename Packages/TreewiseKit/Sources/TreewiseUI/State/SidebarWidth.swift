/// The sidebar's width in points (ADR 0093): its range, the folder side's least width
/// beside it, and the width a window starts at.
public enum SidebarWidth {
    public static let minimum = 160.0
    public static let ideal = 260.0
    public static let maximum = 400.0
    /// The folder side's least width: the command bar with its icons only.
    public static let folderMinimum = 380.0
    /// The narrowest window: the narrowest sidebar beside the folder side's least width.
    public static let narrowestWindow = minimum + folderMinimum

    /// The width a window's sidebar starts at: its own, kept with the window, else the
    /// last one the user chose, else the ideal; within the range.
    public static func start(restored: Double?, lastChosen: Double?) -> Double {
        min(maximum, max(minimum, restored ?? lastChosen ?? ideal))
    }
}
