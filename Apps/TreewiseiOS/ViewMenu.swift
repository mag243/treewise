import SwiftUI
import TreewiseCore
import TreewiseUI

/// The toolbar's View menu: the sort order, which a narrow list has no
/// headers for, and the settings shared with the Mac.
struct ViewMenu: View {
    let browser: BrowserState
    let settings: BrowserSettings

    var body: some View {
        Menu {
            ViewMenuItems(browser: browser, settings: settings)
        } label: {
            Label("View", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("viewMenu")
    }
}
