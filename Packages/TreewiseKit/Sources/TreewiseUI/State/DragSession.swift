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

    /// Why the items cannot drop on a target, when there is a reason to tell
    /// (ADR 0076), in the language of `locale`.
    public func refusalText(over target: FileItem, locale: Locale) -> String? {
        TransferPlanner.refusal(target: target).map { FailureMessage.text(for: $0, locale: locale) }
    }

    /// Why the items may not drop on a target, for a drop checked only as it lands, as in
    /// the iPad's table (ADR 0047, amended 2026-11-16); `nil` when they may.
    public func landingRefusalText(
        over target: FileItem, modifiers: DropModifiers, locale: Locale
    ) -> String? {
        guard
            let refusal = TransferPlanner.refusal(
                items: items, target: target, modifiers: modifiers, ancestry: ancestry)
        else { return nil }
        let bundle = Bundle.module.localizationBundle(for: locale)
        switch refusal {
        case .intoItself:
            return String(
                localized: "A folder can’t go into itself.", bundle: bundle, locale: locale)
        case .alreadyThere:
            return String(
                localized: "Already in ‘\(target.name)’.", bundle: bundle, locale: locale)
        case .notAFolder:
            return String(
                localized: "Items can only be dropped on a folder.", bundle: bundle, locale: locale)
        case .notMovable:
            return String(
                localized: "These items can’t be moved or copied.", bundle: bundle, locale: locale)
        case .archiveReadOnly:
            return FailureMessage.text(for: .archiveReadOnly, locale: locale)
        }
    }

    /// The badge over a target for files another app promises to write
    /// (ADR 0020): they are always copied into a folder, whatever the
    /// modifiers; `nil` over anything that is not a folder, or inside an archive.
    public static func promisedBadge(over target: FileItem) -> Badge? {
        target.isContainer && !target.id.isInsideArchive
            ? Badge(mode: .copy, targetName: target.name) : nil
    }
}
