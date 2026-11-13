import Foundation

/// What a paid module needs to know of its licence with every question (ADR 0071): the
/// keys the user entered and the trials' dates. The module keeps nothing between
/// questions (ADR 0057), so the app gives it all each time.
public struct LicenceContext: Hashable, Sendable, Codable {
    /// The licence keys the user entered, for any module.
    public var keys: [String]
    /// When the user started each module's trial, by module id; a module not in it was
    /// never tried (ADR 0088).
    public var trialStarts: [String: Date]
    /// The latest day the app has seen, which only moves forward, to tell a clock set back.
    public var lastSeen: Date?

    /// No keys and no trial yet.
    public static let none = LicenceContext(keys: [], trialStarts: [:], lastSeen: nil)

    /// Creates a context.
    public init(keys: [String], trialStarts: [String: Date], lastSeen: Date?) {
        self.keys = keys
        self.trialStarts = trialStarts
        self.lastSeen = lastSeen
    }

    /// When the user started a module's trial, or nil when they never did.
    public func trialStart(of moduleID: String) -> Date? {
        trialStarts[moduleID]
    }
}
