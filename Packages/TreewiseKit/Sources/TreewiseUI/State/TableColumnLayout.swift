import Foundation
import TreewiseCore

/// A column of the iPad's table beside the name, which always shows (ADR 0125).
public enum FolderColumn: String, CaseIterable, Codable, Sendable {
    case dateModified, dateCreated, dateAdded, size, kind

    /// The column's width until the user gives it one, in points.
    public var defaultWidth: Double {
        switch self {
        case .dateModified, .dateCreated, .dateAdded: 170
        case .size: 90
        case .kind: 160
        }
    }

    /// Whether the column shows until the user chooses otherwise: the dates a file was
    /// made and added show only when chosen (ADR 0127).
    public var isShownByDefault: Bool {
        switch self {
        case .dateModified, .size, .kind: true
        case .dateCreated, .dateAdded: false
        }
    }

    /// The sort column it stands for.
    public var sortColumn: SortColumn {
        switch self {
        case .dateModified: .dateModified
        case .dateCreated: .dateCreated
        case .dateAdded: .dateAdded
        case .size: .size
        case .kind: .kind
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

    private enum CodingKeys: String, CodingKey {
        case flipped = "hidden"
        case widths
    }

    /// Every column showing at its default width.
    public init() {}

    /// The columns that show, in the table's order.
    public var shown: [FolderColumn] {
        FolderColumn.allCases.filter(isShown)
    }

    /// Whether `column` shows.
    public func isShown(_ column: FolderColumn) -> Bool {
        column.isShownByDefault != flipped.contains(column)
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
