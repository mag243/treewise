import Foundation

/// A column of the iPad's table beside the name, which always shows (ADR 0125).
public enum FolderColumn: String, CaseIterable, Codable, Sendable {
    case dateModified, size, kind

    /// The column's width until the user gives it one, in points.
    public var defaultWidth: Double {
        switch self {
        case .dateModified: 170
        case .size: 90
        case .kind: 160
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

    private var hidden: Set<FolderColumn> = []
    private var widths: [FolderColumn: Double] = [:]

    /// Every column showing at its default width.
    public init() {}

    /// The columns that show, in the table's order.
    public var shown: [FolderColumn] {
        FolderColumn.allCases.filter { !hidden.contains($0) }
    }

    /// Whether `column` shows.
    public func isShown(_ column: FolderColumn) -> Bool {
        !hidden.contains(column)
    }

    /// Hides `column` when it shows, else shows it again in its place.
    public mutating func toggle(_ column: FolderColumn) {
        if hidden.remove(column) == nil { hidden.insert(column) }
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
