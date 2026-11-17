import SwiftUI
import TreewiseCore
import TreewiseUI

/// The failure alert, which offers Delete Permanently… when Move to Trash failed for want
/// of a Trash, and the confirmation that follows (ADR 0128).
struct PermanentDeleteAlert: ViewModifier {
    let browser: BrowserState
    /// Why the last operation failed, as the alert says it.
    let failureText: String
    /// The items the user is asked to delete for good; empty while not asked.
    @State private var deleting: [FileItem] = []

    func body(content: Content) -> some View {
        content
            .alert(failureText, isPresented: isShowingFailure) {
                if !browser.itemsWithoutTrash.isEmpty {
                    Button("Delete Permanently…", role: .destructive) {
                        deleting = browser.itemsWithoutTrash
                    }
                }
                Button("OK", role: .cancel) {}
            }
            .alert(confirmationTitle, isPresented: isConfirming) {
                Button("Delete", role: .destructive) {
                    let items = deleting
                    Task { await browser.deletePermanently(items) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This location has no Trash, so this can’t be undone.")
            }
    }

    private var isShowingFailure: Binding<Bool> {
        Binding(get: { browser.failure != nil }, set: { if !$0 { browser.clearFailure() } })
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { !deleting.isEmpty }, set: { if !$0 { deleting = [] } })
    }

    private var confirmationTitle: String {
        if let item = deleting.first, deleting.count == 1 {
            return String(localized: "Delete “\(item.name)” permanently?")
        }
        return String(localized: "Delete \(deleting.count) items permanently?")
    }
}
