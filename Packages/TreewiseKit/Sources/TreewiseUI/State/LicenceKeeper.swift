import Foundation
import TreewiseCore
import TreewiseModuleInterface

/// A secure store in memory, for tests, UI tests and screenshots.
public final class MemorySecureStore: SecureValueStoring {
    private var values: [String: String] = [:]

    /// Creates an empty store.
    public init() {}

    public func value(for key: String) -> String? { values[key] }

    public func setValue(_ value: String?, for key: String) { values[key] = value }
}

/// What the app keeps of licences (ADR 0071): the keys the user entered, with the app's
/// settings, the trial's start in those settings and in the secure store, and the latest
/// day seen in the secure store. It reads no key: the closed modules check them.
@MainActor
public final class LicenceKeeper {
    /// Where the trial's start is kept in the secure store.
    public static let trialStartKey = "licence.trialStart"
    /// Where the latest day seen is kept in the secure store.
    public static let lastSeenKey = "licence.lastSeen"
    /// How a key's text starts; anything else is no key at all.
    private static let keyPrefix = "TW1-"

    private let settings: BrowserSettings
    private let secure: any SecureValueStoring
    private let now: () -> Date
    private let givenTrialStart: Date?

    /// Creates a keeper. A trial start given at launch, as a Debug build allows, stands in
    /// for the one kept, to try a trial's days.
    public init(
        settings: BrowserSettings, secure: any SecureValueStoring,
        now: @escaping () -> Date = Date.init, trialStart: Date? = nil
    ) {
        self.settings = settings
        self.secure = secure
        self.now = now
        givenTrialStart = trialStart
    }

    /// Keeps a key the user entered, without spaces and line breaks, once. Whether it is
    /// valid is the modules' to say; text that is no key at all is refused.
    @discardableResult
    public func add(key text: String) -> Bool {
        let key = text.filter { !$0.isWhitespace }
        guard key.hasPrefix(Self.keyPrefix), key.count > Self.keyPrefix.count else { return false }
        if !settings.licenceKeys.contains(key) { settings.licenceKeys.append(key) }
        return true
    }

    /// The keys and the trial's dates, for a question to a module. It moves the latest
    /// day seen forward, and keeps a trial's start in both places when one lost it.
    public func context() -> LicenceContext {
        let today = now()
        let seen = date(secure.value(for: Self.lastSeenKey))
        let latest = max(seen ?? today, today)
        secure.setValue(text(latest), for: Self.lastSeenKey)
        return LicenceContext(
            keys: settings.licenceKeys, trialStart: trialStart(), lastSeen: latest)
    }

    /// Starts the trial when it has not started, and gives the context after.
    public func startTrial() -> LicenceContext {
        if trialStart() == nil {
            let today = text(now())
            settings.licenceTrialStart = today
            secure.setValue(today, for: Self.trialStartKey)
        }
        return context()
    }

    /// The earliest start kept in either place, written back to the place that lost it.
    private func trialStart() -> Date? {
        if let givenTrialStart { return givenTrialStart }
        let kept = [date(settings.licenceTrialStart), date(secure.value(for: Self.trialStartKey))]
            .compactMap(\.self)
        guard let start = kept.min() else { return nil }
        settings.licenceTrialStart = text(start)
        secure.setValue(text(start), for: Self.trialStartKey)
        return start
    }

    private func text(_ date: Date) -> String {
        date.ISO8601Format()
    }

    private func date(_ text: String?) -> Date? {
        text.flatMap { try? Date($0, strategy: .iso8601) }
    }
}
