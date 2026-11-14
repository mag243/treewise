import Foundation

/// What a repeating folder of a template stands for one folder per (ADR 0100): `{month}`,
/// `{quarter}` or `{half}` in its name.
public enum FolderRepeat: String, CaseIterable, Hashable, Sendable {
    /// `{month}`, in a month's format of a date field, `MM` without one.
    case month
    /// `{quarter}`, written `1` to `4`.
    case quarter
    /// `{half}`, written `1` or `2`.
    case half

    /// How many folders it stands for in a year.
    public var count: Int {
        switch self {
        case .month: 12
        case .quarter: 4
        case .half: 2
        }
    }
}
