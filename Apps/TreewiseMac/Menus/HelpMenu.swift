import AppKit

/// The Help menu: the download page (ADR 0053), in place of a Help book
/// Treewise does not have. AppKit adds its search field.
@MainActor
enum HelpMenu {
    private nonisolated static let website = URL(string: "https://treewise.m-domain.me/")
    private static let opener = WebsiteOpener()

    static func make() -> NSMenuItem {
        MenuItem.menu(
            "Help",
            [
                MenuItem.make(
                    "Treewise Website", #selector(WebsiteOpener.openWebsite(_:)), target: opener)
            ])
    }

    /// Opens the website, as a menu item's target.
    final class WebsiteOpener: NSObject {
        @objc func openWebsite(_ sender: Any?) {
            if let url = HelpMenu.website { NSWorkspace.shared.open(url) }
        }
    }
}
