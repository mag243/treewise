import SwiftUI
import TreewiseCore
import TreewiseUI

/// The toolbar's View menu: Suggest Names for the whole folder, which the folder's own menu
/// has too but only on empty space below the rows, the sort order, which a narrow list has
/// no headers for, and the settings shared with the Mac.
struct ViewMenu: View {
    let browser: BrowserState
    let settings: BrowserSettings
    let actions: ItemActions

    var body: some View {
        Menu {
            Section {
                WholeFolderNamesButton(actions: actions)
            }
            ViewMenuItems(browser: browser, settings: settings)
        } label: {
            Label("View", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("viewMenu")
    }
}

/// Suggest Names for the whole folder's files (ADR 0129), where the folder's own menu may
/// have no empty space to open on.
struct WholeFolderNamesButton: View {
    let actions: ItemActions

    var body: some View {
        Button {
            actions.suggestNames(true)
        } label: {
            Label("Suggest Names for Whole Folder…", systemImage: "text.badge.star")
        }
        .disabled(!actions.canSuggestNames)
    }
}
