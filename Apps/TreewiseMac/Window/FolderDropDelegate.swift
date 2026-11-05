import AppKit
import SwiftUI
import TreewiseCore

/// Lets an address bar segment take a drop into its folder (ADR 0003),
/// with the same badge and rules as the list and the sidebar.
struct FolderDropDelegate: DropDelegate {
    let folder: FileItem.ID
    /// Whether the drag is over this target and may drop here; it draws an outline.
    @Binding var isTargeted: Bool
    let drop: DropAction

    func validateDrop(info: DropInfo) -> Bool {
        mode() != nil
    }

    func dropEntered(info: DropInfo) {
        isTargeted = mode() != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let mode = mode()
        isTargeted = mode != nil
        return DropProposal(operation: mode.map { $0 == .move ? .move : .copy } ?? .forbidden)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        DropRouting.finish()
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        return DropRouting.perform(
            NSPasteboard(name: .drag), on: DropRouting.item(at: folder), with: drop)
    }

    private func mode() -> TransferMode? {
        DropRouting.mode(of: NSPasteboard(name: .drag), over: DropRouting.item(at: folder))
    }
}

extension View {
    /// Outlines a drop target in the accent color while a drag may drop on it.
    func dropOutline(_ isTargeted: Bool, cornerRadius: CGFloat) -> some View {
        overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(
                    Color.accentColor, lineWidth: 2)
            }
        }
    }
}
