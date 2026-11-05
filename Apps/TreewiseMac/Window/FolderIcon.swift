import AppKit
import SwiftUI
import TreewiseCore

/// The system's icon for an item, at a given size.
struct FolderIcon: View {
    let id: FileItem.ID
    let size: CGFloat

    var body: some View {
        Image(nsImage: Self.image(for: id))
            .resizable()
            .frame(width: size, height: size)
    }

    /// The icon of an item: the system's for a path, a computer for This Mac,
    /// which is not one (ADR 0044).
    static func image(for id: FileItem.ID) -> NSImage {
        guard id == .computer else { return NSWorkspace.shared.icon(forFile: id.rawValue) }
        return NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil)
            ?? NSImage()
    }
}
