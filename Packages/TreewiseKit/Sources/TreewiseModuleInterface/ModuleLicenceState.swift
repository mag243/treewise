import Foundation

/// What a paid module may do, as it says itself (ADR 0071). The closed module works it out
/// from the keys and the trial; the app only shows it, and offers applying accordingly.
public enum ModuleLicenceState: Hashable, Sendable, Codable {
    /// A key names it: it works in full, for good or up to and including the day that
    /// starts at `until` (ADR 0077).
    case licensed(licensee: String, until: Date? = nil)
    /// It was never tried: it works only once the user starts its trial, or with a key
    /// (ADR 0088).
    case notTried
    /// Its trial runs: it works in full for these days more.
    case trial(daysLeft: Int)
    /// No key names it and the trial is over: its proposals are shown, not applied.
    case unlicensed
}

extension ModuleLicenceState {
    /// Whether the module may work: with a licence or in its trial, not before its trial
    /// was started nor after it ended (ADR 0071, ADR 0088).
    public var mayWork: Bool {
        switch self {
        case .licensed, .trial: true
        case .notTried, .unlicensed: false
        }
    }

    /// The days a key with an end date still counts, its last day counted as one; nil for
    /// a key for good and for any other state.
    public func daysLeft(now: Date, calendar: Calendar) -> Int? {
        guard case .licensed(_, let until?) = self else { return nil }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: until)
        ).day
        return days.map { $0 + 1 }
    }
}
