import CoreTransferable
import UniformTypeIdentifiers

/// What a row carries in a drag inside Treewise: the path of its item, in a type of
/// Treewise's own declared in the app's Info.plist, as a drag does not carry a file URL
/// from a row to a drop in the same app (ADR 0047).
struct DraggedItem: Codable, Transferable {
    let path: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .treewiseItem)
    }
}

extension UTType {
    /// An item dragged inside Treewise.
    static let treewiseItem = UTType(exportedAs: "me.m-domain.treewise.item")
}
