import AppKit
import SwiftUI
import TreewiseModuleInterface
import TreewiseUI

/// Enter Licence Key…, as Settings and the review's add-ons header offer it (ADR 0071): a
/// field for the key, and what it unlocked or why it unlocks nothing. The closed modules
/// judge the key; the app keeps it only when one takes it.
struct LicenceKeyEntry: ViewModifier {
    @Binding var isPresented: Bool
    let keeper: LicenceKeeper?
    let host: any NameModuleHosting
    /// Called when a key unlocked an add-on, to show it at once.
    let onUnlocked: () -> Void

    @State private var key = ""
    @State private var outcome: String?

    func body(content: Content) -> some View {
        content
            .alert("Enter Licence Key", isPresented: $isPresented) {
                TextField("TW1-…", text: $key)
                Button("Add") { Task { await enter() } }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Cancel", role: .cancel) { key = "" }
            } message: {
                Text("Paste the licence key from the e-mail you received.")
            }
            .alert(
                outcome ?? "",
                isPresented: Binding(get: { outcome != nil }, set: { if !$0 { outcome = nil } })
            ) {
                Button("OK") { outcome = nil }
            }
    }

    private func enter() async {
        guard let keeper else { return }
        let result = await keeper.enter(key: key, host: host)
        key = ""
        switch result {
        case .notAKey:
            outcome = String(localized: "This is not a Treewise licence key.")
        case .unlocksNothing:
            outcome = String(
                localized:
                    "This key unlocks none of your add-ons. It may be for another add-on, or withdrawn."
            )
        case .unlocked(let modules, let licensee):
            let names = modules.map { NameReviewText.name(ofModule: $0) }.joined(separator: ", ")
            outcome = String(localized: "Unlocked \(names) for \(licensee).")
            onUnlocked()
        }
    }
}

extension View {
    /// Offers Enter Licence Key… while `isPresented`.
    func licenceKeyEntry(
        isPresented: Binding<Bool>, keeper: LicenceKeeper?, host: any NameModuleHosting,
        onUnlocked: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            LicenceKeyEntry(
                isPresented: isPresented, keeper: keeper, host: host, onUnlocked: onUnlocked))
    }
}
