import AppKit

/// The application's menu: About, Check for Updates (ADR 0032), Settings,
/// Services, hiding and quitting, as every Mac app has.
@MainActor
enum AppMenu {
    /// The Services menu, which AppKit fills.
    static let services = NSMenu(title: String(localized: "Services"))

    static func make() -> NSMenuItem {
        let servicesItem = MenuItem.make("Services", nil)
        servicesItem.submenu = services
        return MenuItem.menu(
            "Treewise",
            [
                MenuItem.make(
                    "About Treewise",
                    #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
                MenuItem.make(
                    "Check for Updates…", #selector(AppUpdater.checkForUpdates(_:)),
                    target: AppServices.updater),
                .separator(),
                MenuItem.make("Settings…", #selector(AppDelegate.showSettings(_:)), key: ","),
                .separator(),
                servicesItem,
                .separator(),
                MenuItem.make("Hide Treewise", #selector(NSApplication.hide(_:)), key: "h"),
                MenuItem.make(
                    "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), key: "h",
                    modifiers: [.command, .option]),
                MenuItem.make("Show All", #selector(NSApplication.unhideAllApplications(_:))),
                .separator(),
                MenuItem.make("Quit Treewise", #selector(NSApplication.terminate(_:)), key: "q"),
            ])
    }
}
