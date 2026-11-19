import Foundation
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI
import UniformTypeIdentifiers
import os

/// Dragging items on the iPad (ADR 0047): a row is dragged as a `DraggedItem`, and with its
/// file for other apps; a drop of Treewise's items on a folder goes through the drag rules
/// of PLAN.md §4.1, moving on the same volume and copying across, and a drop the rules
/// forbid changes nothing and says why. Files from another app are received into an inbox
/// in the folder and copied out of it (ADR 0020).
@MainActor
struct ItemDrops {
    private static let logger = Logger(subsystem: LogSubsystem.name, category: "drops")

    let browser: BrowserState
    let locations: Locations
    /// The window dropped on, which asks about names taken and says why a drop is refused.
    let window: BrowserWindow
    let undoManager: UndoManager?

    /// What a dragged row carries: its item, named as the item, and its file, which
    /// another app receives a copy of.
    func provider(for item: FileItem) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.register(DraggedItem(path: item.id.rawValue))
        provider.suggestedName = item.name
        let file = URL(fileURLWithPath: item.id.rawValue)
        let type =
            item.isContainer
            ? UTType.folder : UTType(filenameExtension: file.pathExtension) ?? .data
        provider.registerFileRepresentation(
            forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all
        ) { completion in
            completion(file, false, nil)
            return nil
        }
        return provider
    }

    /// Receives the files another app offers into an inbox in `target`, then copies them
    /// into it, as a drop from another app always copies, and removes the inbox.
    func receive(_ providers: [NSItemProvider], into target: FileItem) {
        guard let folder = target.id.diskURL,
            let inbox = try? PromiseInbox.make(in: folder)
        else {
            Self.logger.error("No inbox for a drop from another app")
            return
        }
        let resolver = window.conflicts.resolver()
        Task {
            let arrived = await ProvidedFiles.receive(providers, into: inbox)
            let items = arrived.compactMap {
                locations.item(at: FileItem.ID($0.standardizedFileURL.path))
            }
            if !items.isEmpty {
                await browser.drop(
                    items, onto: target, modifiers: .option, resolver: resolver,
                    undoManager: undoManager)
            }
            do {
                try PromiseInbox.discard(inbox)
            } catch {
                Self.logger.error("An inbox stays: \(error.localizedDescription)")
            }
        }
    }

    /// The dragged items, or `nil` when one is not in the added folders: a drag drops
    /// whole or not at all.
    func items(of dragged: [DraggedItem]) -> [FileItem]? {
        let items = dragged.compactMap { locations.item(at: FileItem.ID($0.path)) }
        return items.isEmpty || items.count != dragged.count ? nil : items
    }

    /// Whether the items move or copy onto `target`, or `nil` where they may not drop.
    func mode(of items: [FileItem], over target: FileItem) -> TransferMode? {
        session(of: items).badge(over: target, modifiers: [])?.mode
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

    /// Drops items on `target`, or says why they may not, as a drop checked as it lands;
    /// `modifiers` force a move or a copy as ⌘ and ⌥ do, as Move to… and Copy to… ask.
    func land(_ items: [FileItem], on target: FileItem, modifiers: DropModifiers = []) {
        if let reason = session(of: items).landingRefusalText(
            over: target, modifiers: modifiers, locale: .autoupdatingCurrent)
        {
            window.dropRefusal = reason
            return
        }
        let resolver = window.conflicts.resolver()
        Task {
            await browser.drop(
                items, onto: target, modifiers: modifiers, resolver: resolver,
                undoManager: undoManager)
        }
    }

    private func session(of items: [FileItem]) -> DragSession {
        DragSession(items: items, ancestry: { LocalFileSystem.ancestry($0) })
    }
}
