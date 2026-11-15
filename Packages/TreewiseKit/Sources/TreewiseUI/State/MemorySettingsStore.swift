import Foundation
import TreewiseCore

/// Settings kept in memory only: a UI test starts from the defaults and
/// leaves nothing behind.
public final class MemorySettingsStore: SettingsStoring {
    private var values: [String: String] = [:]

    /// Creates an empty store.
    public init() {}

    public func setting(_ key: String) -> String? {
        values[key]
    }

    public func setSetting(_ value: String?, for key: String) {
        values[key] = value
    }
}
