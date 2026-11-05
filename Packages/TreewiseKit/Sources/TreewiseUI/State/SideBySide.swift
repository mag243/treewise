import Foundation

/// Where Window Beside and Tile put two windows on a screen (ADR 0037).
public enum SideBySide {
    /// The frames of the left and right window in `screen`, the visible
    /// frame of a display: its halves when a window of `minimumWidth` fits
    /// in each, else each window at the minimum width against its own edge,
    /// overlapping in the middle, and at most the screen's width.
    public static func frames(in screen: CGRect, minimumWidth: CGFloat)
        -> (left: CGRect, right: CGRect)
    {
        let width = min(max(screen.width / 2, minimumWidth), screen.width)
        let left = CGRect(x: screen.minX, y: screen.minY, width: width, height: screen.height)
        let right = CGRect(
            x: screen.maxX - width, y: screen.minY, width: width, height: screen.height)
        return (left, right)
    }
}
