import AppKit
import TreewiseCore

/// A tile of the icon view, as in the prototype: a 64-point icon above a name
/// of at most two lines (ADR 0025). A selected tile shows a gray plate behind
/// its icon and its name on the accent color, gray in an inactive pane.
final class FileGridItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("FileGridItem")
    /// The size of a tile, the prototype's smallest.
    static let tileSize = NSSize(width: 104, height: 104)
    static let iconSize = NSSize(width: 64, height: 64)
    private static let padding: CGFloat = 4
    private static let spacing: CGFloat = 5
    private static let plateRadius: CGFloat = 8
    private static let labelRadius: CGFloat = 5
    private static let fontSize: CGFloat = 12
    private static let nameLines = 2
    /// The alpha of a cut item's tile (PLAN.md §4.3).
    private static let cutAlpha: CGFloat = 0.5

    /// The item the tile shows, so a late thumbnail lands on the right tile.
    private(set) var itemID: FileItem.ID?
    private let plate = NSView()
    private let cloud = CloudStatusView()

    /// Whether the tile's pane is the active pane of the window.
    var isActivePane = true {
        didSet { showSelection() }
    }

    override var isSelected: Bool {
        didSet { showSelection() }
    }

    override func loadView() {
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        let name = NSTextField(wrappingLabelWithString: "")
        // A wrapping label is selectable and would keep a click on the name
        // from the icon view, which selects the tile and renames it (ADR 0039).
        name.isSelectable = false
        name.alignment = .center
        name.font = .systemFont(ofSize: Self.fontSize)
        name.maximumNumberOfLines = Self.nameLines
        name.cell?.truncatesLastVisibleLine = true
        name.wantsLayer = true
        name.layer?.cornerRadius = Self.labelRadius
        plate.wantsLayer = true
        plate.layer?.cornerRadius = Self.plateRadius
        let tile = NSView()
        for subview in [plate, icon, name, cloud] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            tile.addSubview(subview)
        }
        NSLayoutConstraint.activate(constraints(icon: icon, name: name, in: tile))
        view = tile
        imageView = icon
        textField = name
    }

    /// Shows an item with its name as the setting writes it and an icon.
    func show(_ item: FileItem, name: String, icon: NSImage, isCut: Bool) {
        itemID = item.id
        textField?.stringValue = name
        imageView?.image = icon
        imageView?.setAccessibilityElement(false)
        view.alphaValue = isCut ? Self.cutAlpha : 1
    }

    /// Shows the file's cloud status; see `CloudStatusView`.
    func showCloudStatus(isOnlyOnline: Bool, download: Double?) {
        cloud.show(isOnlyOnline: isOnlyOnline, download: download)
    }

    /// Shows a thumbnail made later, when the tile still shows its item.
    func showThumbnail(_ image: NSImage, of id: FileItem.ID) {
        guard id == itemID else { return }
        imageView?.image = image
    }

    private func showSelection() {
        let highlight: NSColor =
            isActivePane ? .controlAccentColor : .unemphasizedSelectedContentBackgroundColor
        plate.layer?.backgroundColor = isSelected ? NSColor.quaternaryLabelColor.cgColor : nil
        textField?.layer?.backgroundColor = isSelected ? highlight.cgColor : nil
        textField?.textColor =
            isSelected && isActivePane ? .alternateSelectedControlTextColor : .labelColor
    }

    private func constraints(icon: NSImageView, name: NSTextField, in tile: NSView)
        -> [NSLayoutConstraint]
    {
        [
            icon.topAnchor.constraint(equalTo: tile.topAnchor, constant: Self.padding * 2),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: Self.iconSize.width),
            icon.heightAnchor.constraint(equalToConstant: Self.iconSize.height),
            plate.topAnchor.constraint(equalTo: icon.topAnchor, constant: -Self.padding),
            plate.bottomAnchor.constraint(equalTo: icon.bottomAnchor, constant: Self.padding),
            plate.leadingAnchor.constraint(equalTo: icon.leadingAnchor, constant: -Self.padding),
            plate.trailingAnchor.constraint(equalTo: icon.trailingAnchor, constant: Self.padding),
            cloud.trailingAnchor.constraint(equalTo: plate.trailingAnchor),
            cloud.bottomAnchor.constraint(equalTo: plate.bottomAnchor),
            name.topAnchor.constraint(equalTo: plate.bottomAnchor, constant: Self.spacing),
            name.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            name.widthAnchor.constraint(
                lessThanOrEqualTo: tile.widthAnchor, constant: -Self.padding * 2),
        ]
    }
}
