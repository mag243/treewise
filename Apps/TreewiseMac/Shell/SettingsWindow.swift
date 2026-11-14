import AppKit

/// The Settings window (⌘,), as Mac apps have it (ADR 0081): a tab view in the
/// window's toolbar with General, Names (ADR 0057), Templates while the add-on that makes
/// them is there (ADR 0091, ADR 0095) and Add-ons (ADR 0070),
/// laid out as Mac apps lay out settings. It opens on General each time, and
/// changes apply at once.
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
        if let tabs = controller.contentViewController as? NSTabViewController {
            tabs.selectedTabViewItemIndex = 0
            showTemplatesTab(in: tabs)
            Task {
                await FolderTemplatesService.refresh(
                    licences: LaunchOptions.licenceKeeper(for: AppServices.settings))
                showTemplatesTab(in: tabs)
            }
        }
        controller.window?.center()
        controller.showWindow(nil)
    }

    private static let templatesTab = "templates"
    /// Where the Templates tab goes: after General and Names.
    private static let templatesTabIndex = 2

    /// Adds or takes away the Templates tab: it is there in a build with the add-on, while
    /// the add-on may work or templates are saved (ADR 0095).
    private static func showTemplatesTab(in tabs: NSTabViewController) {
        let shown = tabs.tabViewItems.firstIndex { $0.identifier as? String == templatesTab }
        let wanted =
            FolderTemplatesService.addOnID != nil
            && (FolderTemplatesService.mayWork
                || !FolderTemplatesService.templates.templates.isEmpty)
        if wanted, shown == nil {
            let openAddOns = { [weak tabs] in
                guard let tabs else { return }
                tabs.selectedTabViewItemIndex = tabs.tabViewItems.count - 1
            }
            let tab = TemplatesSettingsTab(
                model: FolderTemplatesService.templates, openAddOns: openAddOns)
            let item = pane(tab, "Templates", "folder.badge.gearshape")
            item.identifier = templatesTab
            tabs.insertTabViewItem(item, at: templatesTabIndex)
        } else if !wanted, let shown {
            tabs.removeTabViewItem(tabs.tabViewItems[shown])
        }
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
                    settings: settings, licences: LaunchOptions.licenceKeeper(for: settings)),
                "Add-ons", "puzzlepiece.extension"))
        let window = NSWindow(contentViewController: tabs)
        window.identifier = identifier
        window.styleMask = [.titled, .closable]
        window.isRestorable = false
        window.tabbingMode = .disallowed
        return NSWindowController(window: window)
    }

    private static func pane(
        _ controller: NSViewController, _ label: String.LocalizationValue, _ symbol: String
    ) -> NSTabViewItem {
        // The tab view controller titles the window by the chosen tab's controller, not
        // by its label, so the controller carries the label too.
        controller.title = String(localized: label)
        let item = NSTabViewItem(viewController: controller)
        item.label = String(localized: label)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: item.label)
        return item
    }
}
