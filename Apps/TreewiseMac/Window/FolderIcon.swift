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
            .scaledToFit()
            .frame(width: size, height: size)
    }

    /// The icon of an item: the system's for a path, a computer for This Mac, which is not
    /// one (ADR 0044), and a house for the home folder, as the system's is hard to tell from
    /// another folder at the small sizes of the sidebar and the address bar.
    static func image(for id: FileItem.ID) -> NSImage {
        if id == .computer {
            return NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil)
                ?? NSImage()
        }
        if isHome(id) { return house }
        return NSWorkspace.shared.icon(forFile: id.rawValue)
    }

    /// Whether the item is the home folder, which shows a house.
    static func isHome(_ id: FileItem.ID) -> Bool {
        id.rawValue == LaunchOptions.homeFolder.path
    }

    /// A house in the blue of the folders around it.
    private static var house: NSImage {
        let blue = NSImage.SymbolConfiguration(paletteColors: [.systemBlue])
        return NSImage(
            systemSymbolName: "house.fill", accessibilityDescription: String(localized: "Home")
        )?.withSymbolConfiguration(blue) ?? NSImage()
    }
}
