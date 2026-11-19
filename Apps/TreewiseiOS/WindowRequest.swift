import Foundation
import TreewiseUI

/// The value a Treewise window presents (ADR 0134), which iPadOS keeps with the window and
/// gives back when it restores it: who the window is, and where it was.
struct WindowRequest: Codable, Hashable {
    /// The window's identity; every window opened gets a new one, so opening a folder
    /// always opens a window instead of bringing one forward.
    var id: UUID
    /// The window's `WindowSnapshot`, encoded, as it was when it was last left; `nil` for a
    /// window not shown yet that no folder was asked for.
    var snapshot: Data?

    init(id: UUID = UUID(), showing snapshot: WindowSnapshot? = nil) {
        self.id = id
        self.snapshot = snapshot.flatMap { try? Self.encoder.encode($0) }
    }

    /// Encodes the same snapshot to the same bytes, so a window that did not move keeps an
    /// equal request and SwiftUI sees no change.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    /// Where the window opens.
    var opening: WindowSnapshot? {
        snapshot.flatMap { try? JSONDecoder().decode(WindowSnapshot.self, from: $0) }
    }
}
