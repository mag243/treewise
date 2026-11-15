import AppKit

/// Taking an add-on card to drag it (ADR 0106): on its header, where its icon turns into the
/// grip and the pointer into an open hand, and not on the switch there or the body below.
extension AddOnCardView {
    /// Whether a drag may start at `point`, in the card's coordinates: on its header, as a
    /// window by its title bar, and not on the switch there, which is clicked.
    func grips(at point: NSPoint) -> Bool {
        guard module.proposesNames, let headerView else { return false }
        let header = convert(headerView.bounds, from: headerView)
        // The header's band across the whole card, its margin above included.
        let band = NSRect(
            x: bounds.minX, y: header.minY, width: bounds.width, height: header.height
        )
        .union(
            NSRect(x: bounds.minX, y: header.maxY, width: bounds.width, height: Self.padding.height)
        )
        if let switchView, switchView.convert(switchView.bounds, to: self).contains(point) {
            return false
        }
        return band.contains(point)
    }

    override func mouseEntered(with event: NSEvent) {
        follow(event)
    }

    override func mouseMoved(with event: NSEvent) {
        follow(event)
    }

    override func cursorUpdate(with event: NSEvent) {
        follow(event)
    }

    override func mouseExited(with event: NSEvent) {
        show(Self.addOnSymbol)
        NSCursor.arrow.set()
    }

    /// The grip in the icon and an open hand while the pointer is where the card is taken.
    private func follow(_ event: NSEvent) {
        let grips = grips(at: convert(event.locationInWindow, from: nil))
        show(grips ? Self.gripSymbol : Self.addOnSymbol)
        (grips ? NSCursor.openHand : NSCursor.arrow).set()
    }

    func show(_ name: String) {
        symbol.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }
}
