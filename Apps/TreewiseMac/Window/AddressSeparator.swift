import AppKit
import SwiftUI
import TreewiseCore

/// The separator after a folder in the address bar: a chevron that opens a
/// menu of the folders inside it and points down while the menu is open, as
/// in Explorer. SwiftUI's `Menu` does not tell when its menu opens or
/// closes, so this is a button that pops up its own `NSMenu`, which returns
/// once the menu closes.
struct AddressSeparator: NSViewRepresentable {
    let folders: [FileItem]
    let label: String
    let open: (FileItem.ID) -> Void

    func makeNSView(context: Context) -> ChevronButton {
        ChevronButton()
    }

    func updateNSView(_ button: ChevronButton, context: Context) {
        button.folders = folders
        button.open = open
        button.setAccessibilityLabel(label)
    }

    @MainActor
    final class ChevronButton: NSButton {
        private static let pointSize: CGFloat = 11
        /// The space between the button and the menu below it.
        private static let menuGap: CGFloat = 8

        var folders: [FileItem] = []
        var open: (FileItem.ID) -> Void = { _ in }

        init() {
            super.init(frame: .zero)
            isBordered = false
            imagePosition = .imageOnly
            contentTintColor = .secondaryLabelColor
            point(down: false)
            target = self
            action = #selector(showMenu)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        @objc private func showMenu() {
            let menu = NSMenu()
            for (index, folder) in folders.enumerated() {
                let item = NSMenuItem(
                    title: folder.name, action: #selector(choose(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                menu.addItem(item)
            }
            point(down: true)
            defer { point(down: false) }
            let below = isFlipped ? bounds.maxY + Self.menuGap : bounds.minY - Self.menuGap
            menu.popUp(positioning: nil, at: CGPoint(x: bounds.minX, y: below), in: self)
        }

        @objc private func choose(_ item: NSMenuItem) {
            guard folders.indices.contains(item.tag) else { return }
            open(folders[item.tag].id)
        }

        private func point(down: Bool) {
            let configuration = NSImage.SymbolConfiguration(
                pointSize: Self.pointSize, weight: .regular, scale: .medium)
            image = NSImage(
                systemSymbolName: down ? "chevron.down" : "chevron.right",
                accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
        }
    }
}
