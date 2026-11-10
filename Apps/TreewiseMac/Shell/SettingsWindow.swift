import AppKit
import SwiftUI

/// The Settings window (⌘,), as Mac apps have it (ADR 0081): a tab view in the
/// window's toolbar with General, Names (ADR 0057) and Add-ons (ADR 0070),
/// each a SwiftUI pane. It opens on General each time, and changes apply at once.
@MainActor
enum SettingsWindow {
    /// The size of every pane: wide enough for long add-on names and patterns,
    /// high enough for lists such as the saved patterns, which scroll beyond it.
    static let paneSize = CGSize(width: 600, height: 600)
    /// The window's identifier, for the UI tests.
    static let identifier = NSUserInterfaceItemIdentifier("TreewiseSettings")

    private static var controller: NSWindowController?

    /// Shows the window, made the first time.
    static func show() {
        let controller = controller ?? make()
        self.controller = controller
        (controller.contentViewController as? NSTabViewController)?.selectedTabViewItemIndex = 0
        controller.window?.center()
        controller.showWindow(nil)
    }

    private static func make() -> NSWindowController {
        let settings = AppServices.settings
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(
            pane(
                SettingsGeneralPane(settings: settings, updater: AppServices.updater),
                "General", "gearshape"))
        tabs.addTabViewItem(pane(SettingsNamesPane(settings: settings), "Names", "textformat"))
        tabs.addTabViewItem(
            pane(
                AddOnsSettingsTab(
                    settings: settings, licences: LaunchOptions.licenceKeeper(for: settings)
                )
                .frame(width: paneSize.width, height: paneSize.height),
                "Add-ons", "puzzlepiece.extension"))
        let window = NSWindow(contentViewController: tabs)
        window.identifier = identifier
        window.styleMask = [.titled, .closable]
        window.isRestorable = false
        window.tabbingMode = .disallowed
        return NSWindowController(window: window)
    }

    private static func pane(
        _ view: some View, _ label: String.LocalizationValue, _ symbol: String
    ) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = .preferredContentSize
        let item = NSTabViewItem(viewController: controller)
        item.label = String(localized: label)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: item.label)
        return item
    }
}
