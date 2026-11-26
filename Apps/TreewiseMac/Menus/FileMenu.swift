import AppKit

/// The File menu: new windows, tabs and folders, opening, the archive and
/// naming commands, and closing (ADR 0022).
@MainActor
enum FileMenu {
    private typealias Window = BrowserWindowController

    static func make() -> NSMenuItem {
        let down = MenuItem.arrow(NSDownArrowFunctionKey)
        let file = MenuItem.menu(
            "File",
            [
                MenuItem.make("New Window", #selector(AppDelegate.newWindow(_:)), key: "n"),
                MenuItem.make("New Tab", #selector(NSResponder.newWindowForTab(_:)), key: "t"),
                .separator(),
                MenuItem.make(
                    "New Folder", #selector(Window.newFolder(_:)), key: "n",
                    modifiers: [.command, .shift]),
                MenuItem.make("Open", #selector(Window.openSelection(_:)), key: down),
                MenuItem.make(
                    "Open on Other Side", #selector(Window.openSelectionInOtherWindow(_:)),
                    key: down, modifiers: [.command, .option]),
            ] + namingAndArchiveItems() + [
                MenuItem.make("Eject", #selector(Window.ejectSelection(_:)), key: "e"),
                MenuItem.make(
                    "Open in Terminal", #selector(Window.openInTerminal(_:)), key: "t",
                    modifiers: [.command, .control]),
                .separator(),
                MenuItem.make("Go to Address", #selector(Window.goToAddress(_:)), key: "l"),
                .separator(),
                MenuItem.make("Close", #selector(NSWindow.performClose(_:)), key: "w"),
            ])
        file.submenu?.delegate = FileMenuTemplates.shared
        return file
    }

    /// Suggest Names, the archive commands and Rename.
    private static func namingAndArchiveItems() -> [NSMenuItem] {
        let compress = MenuItem.make("Compress to", nil)
        compress.submenu = NSMenu(title: compress.title)
        compress.submenu?.items = [
            MenuItem.make("7z File", #selector(Window.compressTo7z(_:))),
            MenuItem.make("TAR.GZ File", #selector(Window.compressToTarGz(_:))),
        ]
        return [
            MenuItem.make("Suggest Names…", #selector(Window.suggestNames(_:))),
            MenuItem.make(
                "Suggest Names for Whole Folder…", #selector(Window.suggestNamesForFolder(_:))),
            MenuItem.make("Extract All…", #selector(Window.extractAll(_:))),
            MenuItem.make("Compress to ZIP", #selector(Window.compressToZip(_:))),
            compress,
            MenuItem.make("Rename", #selector(Window.renameSelection(_:))),
            MenuItem.make("Rename with Suggestions", #selector(Window.renameWithSuggestions(_:))),
        ]
    }
}
