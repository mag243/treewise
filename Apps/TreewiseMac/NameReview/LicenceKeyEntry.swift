import AppKit
import SwiftUI
import TreewiseModuleInterface
import TreewiseUI

/// Enter Licence Key…, as Settings and the review's add-ons header offer it (ADR 0071): a
/// sheet with room for the whole key, Paste, and why a key unlocks nothing, shown in the
/// sheet so the user can try again. The closed modules judge the key; the app keeps it
/// only when one takes it, and then says what it unlocked.
struct LicenceKeyEntry: ViewModifier {
    @Binding var isPresented: Bool
    let keeper: LicenceKeeper?
    let host: any NameModuleHosting
    /// Called when a key unlocked an add-on, to show it at once.
    let onUnlocked: () -> Void

    @State private var unlocked: String?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                LicenceKeySheet(keeper: keeper, host: host) { message in
                    isPresented = false
                    unlocked = message
                    onUnlocked()
                }
            }
            .alert(
                unlocked ?? "",
                isPresented: Binding(get: { unlocked != nil }, set: { if !$0 { unlocked = nil } })
            ) {
                Button("OK") { unlocked = nil }
            }
    }
}

/// The sheet in which a key is pasted.
private struct LicenceKeySheet: View {
    private static let width: CGFloat = 520
    private static let fieldHeight: CGFloat = 110
    private static let cornerRadius: CGFloat = 5

    let keeper: LicenceKeeper?
    let host: any NameModuleHosting
    /// Called with what a key unlocked.
    let onUnlocked: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var problem: String?
    @State private var isChecking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enter Licence Key").font(.headline)
            Text("Paste the licence key from the e-mail you received.")
                .foregroundStyle(.secondary)
            TextEditor(text: $key)
                .font(.body.monospaced())
                .frame(height: Self.fieldHeight)
                .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius).stroke(.quaternary))
                .accessibilityLabel(Text("Licence key"))
                .onChange(of: key) { problem = nil }
            HStack {
                Button("Paste") {
                    if let text = NSPasteboard.general.string(forType: .string) { key = text }
                }
                if let problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { Task { await enter() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        isChecking || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: Self.width)
    }

    private func enter() async {
        guard let keeper else { return }
        isChecking = true
        defer { isChecking = false }
        switch await keeper.enter(key: key, host: host) {
        case .notAKey:
            problem = String(localized: "This is not a Treewise licence key.")
        case .unlocksNothing:
            problem = String(
                localized:
                    "This key unlocks none of your add-ons. It may be for another add-on, or withdrawn."
            )
        case .unlocked(let modules, let licensee):
            let names = modules.map { NameReviewText.name(ofModule: $0) }.joined(separator: ", ")
            onUnlocked(String(localized: "Unlocked \(names) for \(licensee)."))
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
