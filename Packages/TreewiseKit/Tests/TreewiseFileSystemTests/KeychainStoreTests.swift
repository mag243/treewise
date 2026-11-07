import Foundation
import Testing
import TreewiseFileSystem

/// Values kept in the keychain, under a service of the test's own that it removes again.
@Suite struct KeychainStoreTests {
    // The data protection keychain needs a process signed with the team, which a package's
    // test runner is not; the app reaches it.
    @Test(.enabled(if: KeychainStore.isAvailable))
    func keepsReplacesAndRemovesAValue() {
        let store = KeychainStore(service: "me.m-domain.treewise.tests.\(UUID().uuidString)")
        defer { store.setValue(nil, for: "a") }
        #expect(store.value(for: "a") == nil)
        store.setValue("1", for: "a")
        #expect(store.value(for: "a") == "1")
        store.setValue("2", for: "a")
        #expect(store.value(for: "a") == "2")
        store.setValue(nil, for: "a")
        #expect(store.value(for: "a") == nil)
    }
}
