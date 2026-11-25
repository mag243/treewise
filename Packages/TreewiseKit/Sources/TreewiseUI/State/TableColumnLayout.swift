import Foundation
import TreewiseCore

/// A column of the iPad's table beside the name, which always shows (ADR 0125), or of the
/// Mac's list: the Git column only there (ADR 0149).
public enum FolderColumn: String, CaseIterable, Codable, Sendable {
    case dateModified, dateCreated, dateAdded, size, kind, git

    /// The columns the iPad offers: all but Git, as the iPad reads no git state.
    public static let onIPad: [FolderColumn] = allCases.filter { $0 != .git }

    /// The column's width until the user gives it one, in points.
    public var defaultWidth: Double {
        switch self {
        // Room for the longest date with its time, such as `Nov 14, 2026 at 11:36 AM`.
        case .dateModified, .dateCreated, .dateAdded: 220
        case .size: 90
        case .kind: 160
        case .git: 100
        }
    }

    /// Whether the column shows until the user chooses otherwise: the dates a file was
    /// made and added, and the Git column, show only when chosen (ADR 0127, 0149).
    public var isShownByDefault: Bool {
        switch self {
        case .dateModified, .size, .kind: true
        case .dateCreated, .dateAdded, .git: false
        }
    }

    /// The order in which columns give way where the table has too little room: the least
    /// telling first, the date modified last (ADR 0125).
    static let givingWay: [FolderColumn] = [
        .git, .dateAdded, .dateCreated, .kind, .size, .dateModified,
    ]

    /// The sort column it stands for.
    public var sortColumn: SortColumn {
        switch self {
        case .dateModified: .dateModified
        case .dateCreated: .dateCreated
        case .dateAdded: .dateAdded
        case .size: .size
        case .kind: .kind
        case .git: .git
        }
    }
}

/// Which of the iPad table's columns show and how wide each is (ADR 0125); the name takes
/// the rest.
///
/// Invariant: every width kept is between `minimumWidth` and `maximumWidth`.
public struct TableColumnLayout: Codable, Equatable, Sendable {
    /// The narrowest a column may be made.
    public static let minimumWidth = 60.0
    /// The widest a column may be made.
    public static let maximumWidth = 400.0

    /// The columns the user showed or hid against their default. Kept as `hidden`: before
    /// the dates made and added, every column showed by default, so a choice kept then
    /// means the same now.
    private var flipped: Set<FolderColumn> = []
    private var widths: [FolderColumn: Double] = [:]
    /// The chosen columns left out for want of room, by `fitted(into:spacing:)`; not kept.
    private var crowdedOut: Set<FolderColumn> = []

    private enum CodingKeys: String, CodingKey {
        case flipped = "hidden"
        case widths
    }

    /// Every column showing at its default width.
    public init() {}

    /// The columns that show, in the table's order: those chosen, less those left out for
    /// want of room.
    public var shown: [FolderColumn] {
        FolderColumn.allCases.filter { isShown($0) && !crowdedOut.contains($0) }
    }

    /// Whether `column` is chosen to show.
    public func isShown(_ column: FolderColumn) -> Bool {
        column.isShownByDefault != flipped.contains(column)
    }

    /// Whether `column` is chosen but left out, as the table has too little room for it.
    public func isCrowdedOut(_ column: FolderColumn) -> Bool {
        crowdedOut.contains(column)
    }

    /// The layout with the chosen columns that fit in `room` points, each column taking its
    /// width and `spacing`; columns give way in `FolderColumn.givingWay`'s order.
    public func fitted(into room: Double, spacing: Double) -> TableColumnLayout {
        var fitted = self
        fitted.crowdedOut = []
        var needed = FolderColumn.allCases.filter(isShown).map { width(of: $0) + spacing }
            .reduce(0, +)
        for column in FolderColumn.givingWay where needed > room && fitted.isShown(column) {
            fitted.crowdedOut.insert(column)
            needed -= width(of: column) + spacing
        }
        return fitted
    }

    /// Hides `column` when it shows, else shows it in its place.
    public mutating func toggle(_ column: FolderColumn) {
        if flipped.remove(column) == nil { flipped.insert(column) }
    }

    /// The width of `column`: the one the user gave it, else its default.
    public func width(of column: FolderColumn) -> Double {
        widths[column] ?? column.defaultWidth
    }

    /// Gives `column` the width `width`, kept within the bounds.
    public mutating func setWidth(_ width: Double, of column: FolderColumn) {
        widths[column] = min(max(width, Self.minimumWidth), Self.maximumWidth)
    }

    /// Gives `column` its default width back.
    public mutating func resetWidth(of column: FolderColumn) {
        widths[column] = nil
    }
}
