import Foundation
import Security
import TreewiseCore

/// Small values kept in the keychain as generic passwords of one service, on this device
/// only: resetting the app's settings does not remove them (ADR 0071). It is the data
/// protection keychain, reached by the team the app is signed with, which never asks the
/// user: the older file keychain asks after every new build, as if the app wanted their
/// passwords. A build not signed with the team cannot reach it, and reads nothing.
public final class KeychainStore: SecureValueStoring {
    /// The service of the app's own values.
    public static let appService = "me.m-domain.treewise.licence"

    private let service: String

    /// Whether this process can reach the data protection keychain: an app signed with the
    /// team can, a test runner or a build without signing cannot.
    public static var isAvailable: Bool {
        let probe = KeychainStore(service: appService + ".probe")
        let key = UUID().uuidString
        probe.setValue("1", for: key)
        defer { probe.setValue(nil, for: key) }
        return probe.value(for: key) == "1"
    }

    /// A store for the values of `service`.
    public init(service: String = appService) {
        self.service = service
    }

    /// The value kept under `key`, or nil when there is none or the keychain cannot be read.
    public func value(for key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Keeps `value` under `key`, replacing what was there; nil removes it.
    public func setValue(_ value: String?, for key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard let value else { return }
        var item = baseQuery(for: key)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }
}
