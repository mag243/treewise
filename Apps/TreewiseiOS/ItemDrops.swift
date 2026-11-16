import Foundation
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import os

/// Dragging items inside the iPad app (ADR 0047): a row is dragged as a `DraggedItem`, and a
/// drop on a folder goes through the drag rules of PLAN.md §4.1, moving on the same volume
/// and copying across. A drop the rules forbid changes nothing and says why.
@MainActor
struct ItemDrops {
    private static let logger = Logger(subsystem: LogSubsystem.name, category: "drops")

    let browser: BrowserState
    let locations: Locations
    let undoManager: UndoManager?

    /// What a dragged row carries: its item, named as the item.
    func provider(for item: FileItem) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.register(DraggedItem(path: item.id.rawValue))
        provider.suggestedName = item.name
        return provider
    }

    /// The dragged items, or `nil` when one is not in the added folders: a drag drops
    /// whole or not at all.
    func items(of dragged: [DraggedItem]) -> [FileItem]? {
        let items = dragged.compactMap { locations.item(at: FileItem.ID($0.path)) }
        return items.isEmpty || items.count != dragged.count ? nil : items
    }

    /// Drops the dragged items that landed on `target`, or says why they may not.
    func land(_ dragged: [DraggedItem], on target: FileItem) {
        Self.logger.info("Landing \(dragged.count) dragged items")
        guard let items = items(of: dragged) else {
            Self.logger.info("A drop carried items not in the added folders")
            return
        }
        land(items, on: target)
    }

    /// Drops items on `target`, or says why they may not, as a drop checked as it lands.
    func land(_ items: [FileItem], on target: FileItem) {
        if let reason = session(of: items).landingRefusalText(
            over: target, modifiers: [], locale: .autoupdatingCurrent)
        {
            locations.dropRefusal = reason
            return
        }
        let resolver = locations.conflicts.resolver()
        Task {
            await browser.drop(
                items, onto: target, modifiers: [], resolver: resolver, undoManager: undoManager)
        }
    }

    private func session(of items: [FileItem]) -> DragSession {
        DragSession(items: items, ancestry: { LocalFileSystem.ancestry($0) })
    }
}
