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
