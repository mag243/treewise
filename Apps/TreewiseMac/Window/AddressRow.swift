import SwiftUI
import TreewiseUI

/// The address bar as a row of the window, under the tab bar and over the
/// command bar (ADR 0037): it takes the window's whole width and is never
/// hidden, however narrow the window.
struct AddressRow: View {
    private static let height: CGFloat = 26
    private static let cornerRadius: CGFloat = 6
    private static let padding: CGFloat = 6

    let browser: BrowserState
    @Binding var isEditing: Bool

    var body: some View {
        AddressBar(
            browser: browser, paneIndex: browser.layout.focusedPaneIndex,
            folder: browser.layout.focusedPane.activeTab.folder, isEditing: $isEditing
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
        .padding(Self.padding)
    }
}
