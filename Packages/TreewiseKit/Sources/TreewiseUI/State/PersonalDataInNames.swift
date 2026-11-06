/// What Approve All does with a proposed name that holds personal data (ADR 0060).
public enum PersonalDataInNames: String, Hashable, Sendable, CaseIterable {
    /// Approve All leaves the row out; the user can approve it on its own.
    case leaveOutOfApproveAll
    /// Approve All takes the row like any other; the warning stays.
    case onlyWarn
}
