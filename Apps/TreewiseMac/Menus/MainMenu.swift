import AppKit

/// Treewise's menu bar, built with AppKit (ADR 0080, ADR 0081). Its items are
/// made once; whether each can be chosen is asked of its target just before
/// a menu opens or a key is pressed, so a menu is never replaced while it is
/// open. The titles, order and keys are those of the README's table.
@MainActor
enum MainMenu {
    /// Builds the menu bar and tells AppKit which menus are the Window,
    /// Help and Services menus, to which it adds its own items.
    static func install() {
        let bar = NSMenu()
        let window = WindowMenu.make()
        let help = HelpMenu.make()
        let app = AppMenu.make()
        bar.items = [
            app, FileMenu.make(), EditMenu.make(), ViewMenu.make(), GoMenu.make(), window, help,
        ]
        NSApp.mainMenu = bar
        NSApp.windowsMenu = window.submenu
        NSApp.helpMenu = help.submenu
        NSApp.servicesMenu = AppMenu.services
    }
}
