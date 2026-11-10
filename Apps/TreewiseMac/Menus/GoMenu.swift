import AppKit

/// The Go menu, as Finder has: Back, Forward and Enclosing Folder of the
/// window's folder, the keys of the toolbar's buttons (ADR 0081).
@MainActor
enum GoMenu {
    private typealias Window = BrowserWindowController

    static func make() -> NSMenuItem {
        MenuItem.menu(
            "Go",
            [
                MenuItem.make("Back", #selector(Window.goBack(_:)), key: "["),
                MenuItem.make("Forward", #selector(Window.goForward(_:)), key: "]"),
                MenuItem.make(
                    "Enclosing Folder", #selector(Window.goToEnclosingFolder(_:)),
                    key: MenuItem.arrow(NSUpArrowFunctionKey)),
            ])
    }
}
