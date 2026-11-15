import Foundation
import TreewiseCore

/// Where settings are kept: `UserDefaults`, or memory for tests and UI tests
/// (ADR 0023). Values are kept as text.
public protocol SettingsStoring: AnyObject {
    /// The value kept under `key`, if any.
    func setting(_ key: String) -> String?
    /// Keeps `value` under `key`; `nil` removes it.
    func setSetting(_ value: String?, for key: String)
}

extension UserDefaults: SettingsStoring {
    public func setting(_ key: String) -> String? {
        string(forKey: key)
    }

    public func setSetting(_ value: String?, for key: String) {
        set(value, forKey: key)
    }
}
