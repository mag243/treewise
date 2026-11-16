import CoreTransferable
import Foundation
import TreewiseCore
import UniformTypeIdentifiers
import os

/// What a row carries in a drag inside Treewise: the path of its item, in a type of
/// Treewise's own declared in the app's Info.plist, as a drag does not carry a file URL
/// from a row to a drop in the same app (ADR 0047).
struct DraggedItem: Codable, Transferable {
    let path: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .treewiseItem)
    }

    private static let logger = Logger(subsystem: LogSubsystem.name, category: "drops")

    /// The dragged item a drop's provider carries, read once the drop has landed: iPadOS
    /// lets a drop's items be read only then.
    @MainActor
    static func load(from provider: NSItemProvider) async -> DraggedItem? {
        await withCheckedContinuation { continuation in
            _ = provider.loadTransferable(type: DraggedItem.self) { result in
                if case .failure(let error) = result {
                    logger.error("A dropped item could not be read: \(error.localizedDescription)")
                }
                continuation.resume(returning: try? result.get())
            }
        }
    }
}

extension UTType {
    /// An item dragged inside Treewise.
    static let treewiseItem = UTType(exportedAs: "me.m-domain.treewise.item")
}
