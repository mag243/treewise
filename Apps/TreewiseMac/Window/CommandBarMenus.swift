import AppKit
import TreewiseCore
import TreewiseUI

/// The menus of the command bar's New, Sort and View buttons, built each
/// time one opens, so they show the window's state as it is then.
@MainActor
final class CommandBarMenus: NSObject, NSMenuDelegate {
    private static let sortColumns: [(SortColumn, String.LocalizationValue)] = [
        (.name, "Name"), (.dateModified, "Date Modified"), (.kind, "Kind"), (.size, "Size"),
    ]
    private static let densities: [(RowDensity, String.LocalizationValue)] = [
        (.small, "Small"), (.medium, "Medium"), (.large, "Large"),
    ]

    private let browser: BrowserState
    let new = NSMenu()
    let sort = NSMenu()
    let view = NSMenu()
    /// The first item of each menu, which a pull-down button shows as its own title.
    private var titles: [NSMenu: NSMenuItem] = [:]

    init(browser: BrowserState) {
        self.browser = browser
        super.init()
        for menu in [new, sort, view] {
            menu.delegate = self
            menu.autoenablesItems = false
        }
    }

    /// Makes `item` the title of `menu`'s button.
    func setTitle(_ item: NSMenuItem, of menu: NSMenu) {
        titles[menu] = item
        menu.removeAllItems()
        menu.addItem(item)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let title = titles[menu] else { return }
        menu.removeAllItems()
        menu.addItem(title)
        let items: [NSMenuItem] =
            switch menu {
            case new: newItems
            case sort: sortItems
            default: viewItems
            }
        for item in items { menu.addItem(item) }
    }

    // MARK: - New

    private var newItems: [NSMenuItem] {
        let folder = item(
            "New Folder", image: "folder.badge.plus", enabled: browser.canAddItems
        ) { [browser] in
            Task { await browser.newFolder(undoManager: SharedUndo.manager) }
        }
        return [folder]
    }

    // MARK: - Sort

    private var sortItems: [NSMenuItem] {
        let sort = browser.sort
        var items = [NSMenuItem.sectionHeader(title: String(localized: "Sort By"))]
        for (column, title) in Self.sortColumns {
            items.append(
                item(title, checked: sort.column == column) { [browser] in
                    browser.sort(by: column, ascending: browser.sort.ascending)
                })
        }
        items.append(.separator())
        items.append(.sectionHeader(title: String(localized: "Order")))
        for (ascending, title) in [(true, "Ascending"), (false, "Descending")]
            as [(Bool, String.LocalizationValue)]
        {
            items.append(
                item(title, checked: sort.ascending == ascending) { [browser] in
                    browser.sort(by: browser.sort.column, ascending: ascending)
                })
        }
        return items
    }

    // MARK: - View

    private var viewItems: [NSMenuItem] {
        let settings = browser.settings
        var items = [NSMenuItem.sectionHeader(title: String(localized: "View"))]
        items.append(viewModeItem(.icons, "as Icons", image: "square.grid.2x2"))
        items.append(viewModeItem(.list, "as List", image: "list.bullet"))
        let rowSize = NSMenuItem(
            title: String(localized: "Row Size"), action: nil, keyEquivalent: "")
        let sizes = NSMenu()
        sizes.autoenablesItems = false
        for (density, title) in Self.densities {
            sizes.addItem(
                item(title, checked: settings.rowDensity == density) {
                    settings.rowDensity = density
                })
        }
        rowSize.submenu = sizes
        items += [rowSize, .separator()]
        items.append(
            item("Show Hidden Files", checked: settings.showsHiddenFiles) {
                settings.showsHiddenFiles.toggle()
            })
        items.append(
            item("Show File Extensions", checked: settings.showsExtensions) {
                settings.showsExtensions.toggle()
            })
        return items
    }

    private func viewModeItem(
        _ mode: ViewMode, _ title: String.LocalizationValue, image symbol: String
    ) -> NSMenuItem {
        item(title, image: symbol, checked: browser.viewMode == mode) { [browser] in
            browser.viewMode = mode
        }
    }

    // MARK: - Items

    private func item(
        _ title: String.LocalizationValue, image symbol: String? = nil, checked: Bool = false,
        enabled: Bool = true, run: @escaping @MainActor () -> Void
    ) -> NSMenuItem {
        let item = ActionMenuItem(title: String(localized: title), run: run)
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        item.state = checked ? .on : .off
        item.isEnabled = enabled
        return item
    }
}

/// A menu item that runs a closure when chosen.
@MainActor
final class ActionMenuItem: NSMenuItem {
    private let run: @MainActor () -> Void

    init(title: String, run: @escaping @MainActor () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(runAction), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func runAction() {
        run()
    }
}
