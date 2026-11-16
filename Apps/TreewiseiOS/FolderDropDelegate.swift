import SwiftUI
import TreewiseCore
import UniformTypeIdentifiers
import os

/// A folder that takes items dragged inside Treewise: the table's and the list's rows, the
/// sidebar's locations and the path (ADR 0047, amended 2026-11-16). iPadOS lets a drop's
/// items be read only once they land, so the drag rules are checked then: a drop they
/// forbid changes nothing and says why.
@MainActor
struct FolderDropDelegate: DropDelegate {
    private nonisolated static let logger = Logger(subsystem: LogSubsystem.name, category: "drops")

    let target: FileItem
    let drops: ItemDrops

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.treewiseItem, .item])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.treewiseItem])
        Self.logger.info("A drop of \(providers.count) items landed")
        guard !providers.isEmpty else {
            drops.receive(info.itemProviders(for: [.item]), into: target)
            return true
        }
        let drops = drops
        let target = target
        Task {
            var dragged: [DraggedItem] = []
            for provider in providers {
                if let item = await DraggedItem.load(from: provider) { dragged.append(item) }
            }
            drops.land(dragged, on: target)
        }
        return true
    }
}

extension View {
    /// Takes items dragged inside Treewise onto `target`, checked as they land.
    func takesDrops(on target: FileItem?, with drops: ItemDrops) -> some View {
        modifier(FolderDrop(target: target, drops: drops))
    }
}

/// A view that takes drops on its folder, when it has one.
private struct FolderDrop: ViewModifier {
    let target: FileItem?
    let drops: ItemDrops

    func body(content: Content) -> some View {
        if let target {
            content.onDrop(
                of: [.treewiseItem], delegate: FolderDropDelegate(target: target, drops: drops))
        } else {
            content
        }
    }
}
