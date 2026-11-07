import Foundation

/// What a paid module needs to know of its licence with every question (ADR 0071): the
/// keys the user entered and the trial's dates. The module keeps nothing between
/// questions (ADR 0057), so the app gives it all each time.
public struct LicenceContext: Hashable, Sendable, Codable {
    /// The licence keys the user entered, for any module.
    public var keys: [String]
    /// When the trial started, or nil when it has not.
    public var trialStart: Date?
    /// The latest day the app has seen, which only moves forward, to tell a clock set back.
    public var lastSeen: Date?

    /// No keys and no trial yet.
    public static let none = LicenceContext(keys: [], trialStart: nil, lastSeen: nil)

    /// Creates a context.
    public init(keys: [String], trialStart: Date?, lastSeen: Date?) {
        self.keys = keys
        self.trialStart = trialStart
        self.lastSeen = lastSeen
    }
}
