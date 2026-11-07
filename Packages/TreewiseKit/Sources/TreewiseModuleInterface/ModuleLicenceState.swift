/// What a paid module may do, as it says itself (ADR 0071). The closed module works it out
/// from the keys and the trial; the app only shows it, and offers applying accordingly.
public enum ModuleLicenceState: Hashable, Sendable, Codable {
    /// A key names it: it works in full.
    case licensed(licensee: String)
    /// Its trial runs: it works in full for these days more.
    case trial(daysLeft: Int)
    /// No key names it and the trial is over: its proposals are shown, not applied.
    case unlicensed
}
