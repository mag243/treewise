import AppKit

/// The Window menu: Minimize and Zoom, Window Beside and tiling two windows
/// (ADR 0037), and what AppKit adds for tabs and the list of windows.
@MainActor
enum WindowMenu {
    private typealias Window = BrowserWindowController

    static func make() -> NSMenuItem {
        MenuItem.menu(
            "Window",
            [
                MenuItem.make("Minimize", #selector(NSWindow.performMiniaturize(_:)), key: "m"),
                MenuItem.make("Zoom", #selector(NSWindow.performZoom(_:))),
                .separator(),
                MenuItem.make(
                    "Window Beside", #selector(Window.windowBeside(_:)), key: "n",
                    modifiers: [.command, .option]),
                MenuItem.make(
                    "Tile Windows Side by Side", #selector(Window.tileWithOtherWindow(_:))),
                .separator(),
                MenuItem.make(
                    "Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
            ])
    }
}
