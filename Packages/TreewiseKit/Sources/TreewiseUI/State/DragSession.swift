import Foundation
import TreewiseCore

/// Items being dragged, and what dropping them on a target would do
/// (PLAN.md §4.1, ADR 0003).
public struct DragSession: Sendable {
    /// The badge next to the pointer: "Move to ‘Projects’" or "Copy to ‘Backups’".
    public struct Badge: Sendable, Equatable {
        /// Whether the drop moves or copies.
        public var mode: TransferMode
        /// The name of the folder the items would land in.
        public var targetName: String

        /// Creates a badge.
        public init(mode: TransferMode, targetName: String) {
            self.mode = mode
            self.targetName = targetName
        }

        /// The badge's text in the language of `locale`.
        public func text(locale: Locale) -> String {
            let bundle = Bundle.module.localizationBundle(for: locale)
            return mode == .move
                ? String(localized: "Move to ‘\(targetName)’", bundle: bundle, locale: locale)
                : String(localized: "Copy to ‘\(targetName)’", bundle: bundle, locale: locale)
        }
    }

    /// The dragged items.
    public let items: [FileItem]
    private let ancestry: @Sendable (FileItem.ID) -> [FileItem.ID]

    /// Starts a drag of items. `ancestry` returns a folder's containers,
    /// nearest first, synchronously: AppKit asks while the pointer moves.
    public init(items: [FileItem], ancestry: @escaping @Sendable (FileItem.ID) -> [FileItem.ID]) {
        self.items = items
        self.ancestry = ancestry
    }

    /// The badge over a target, or `nil` when the items cannot be dropped there.
    public func badge(over target: FileItem, modifiers: DropModifiers) -> Badge? {
        TransferPlanner.plan(items: items, target: target, modifiers: modifiers, ancestry: ancestry)
            .map { Badge(mode: $0, targetName: target.name) }
    }

    /// The badge over a target for files another app promises to write
    /// (ADR 0020): they are always copied into a folder, whatever the
    /// modifiers; `nil` over anything that is not a folder.
    public static func promisedBadge(over target: FileItem) -> Badge? {
        target.isContainer ? Badge(mode: .copy, targetName: target.name) : nil
    }
}
