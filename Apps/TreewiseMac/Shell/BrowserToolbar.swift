import AppKit
import TreewiseUI

/// The toolbar of a browser window (ADR 0081): the sidebar's button, Back,
/// Forward, Enclosing Folder and Refresh for the window's folder (ADR 0037),
/// and the search field. The address bar is a row of the window and the
/// actions are in the command bar. The items' actions go through the
/// responder chain to the window's controller, which also tells whether they
/// can be chosen; their keys are in the Go and View menus.
@MainActor
final class BrowserToolbar: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
    private static let search = NSToolbarItem.Identifier("search")
    private static let back = NSToolbarItem.Identifier("back")
    private static let forward = NSToolbarItem.Identifier("forward")
    private static let enclosing = NSToolbarItem.Identifier("enclosing")
    private static let refresh = NSToolbarItem.Identifier("refresh")
    private static let order: [NSToolbarItem.Identifier] = [
        // The space puts the sidebar's button at the right over the sidebar (ADR 0093).
        .flexibleSpace, .toggleSidebar, .sidebarTrackingSeparator, back, forward, enclosing,
        refresh,
        .flexibleSpace, search,
    ]

    let toolbar = NSToolbar(identifier: "browser")
    private let browser: BrowserState
    private let searchItem = NSSearchToolbarItem(itemIdentifier: search)

    /// The search field, for ⌘F.
    var searchField: NSSearchField { searchItem.searchField }

    init(browser: BrowserState) {
        self.browser = browser
        super.init()
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        searchItem.searchField.delegate = self
    }

    /// Shows the folder's name in the search field's prompt and the query of
    /// the folder shown, which a new folder empties.
    func show(title: String, query: String) {
        searchField.placeholderString = String(localized: "Search \(title)")
        if searchField.stringValue != query { searchField.stringValue = query }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.order
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.order
    }

    func toolbar(
        _ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch identifier {
        case Self.search: searchItem
        case Self.back:
            item(identifier, "Back", "chevron.left", #selector(BrowserWindowController.goBack(_:)))
        case Self.forward:
            item(
                identifier, "Forward", "chevron.right",
                #selector(BrowserWindowController.goForward(_:)))
        case Self.enclosing:
            item(
                identifier, "Enclosing Folder", "arrow.up",
                #selector(BrowserWindowController.goToEnclosingFolder(_:)))
        case Self.refresh: refreshItem()
        default: nil
        }
    }

    private func item(
        _ identifier: NSToolbarItem.Identifier, _ label: String.LocalizationValue,
        _ symbol: String, _ action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        let title = String(localized: label)
        item.label = title
        item.toolTip = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        item.isBordered = true
        item.action = action
        return item
    }

    private func refreshItem() -> NSToolbarItem {
        let item = item(
            Self.refresh, "Refresh", "arrow.clockwise",
            #selector(BrowserWindowController.refreshFolder(_:)))
        item.toolTip = String(localized: "Read the folder again")
        return item
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ notification: Notification) {
        let tab = browser.layout.focusedPane.activeTabID
        browser.setQuery(searchField.stringValue, in: tab)
    }
}
