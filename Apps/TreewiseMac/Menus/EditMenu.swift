import AppKit

/// The Edit menu: Undo and Redo of the window's undo manager, which all
/// browser windows share (ADR 0037), or of the text being edited; the
/// standard pasteboard items; Treewise's own (ADR 0022); Move to ▸ and Copy to ▸
/// (ADR 0147); and Spelling and Grammar for the name being typed (ADR 0084).
@MainActor
enum EditMenu {
    private typealias Window = BrowserWindowController

    static func make() -> NSMenuItem {
        MenuItem.menu(
            "Edit",
            [
                MenuItem.make("Undo", Selector(("undo:")), key: "z"),
                MenuItem.make(
                    "Redo", Selector(("redo:")), key: "z", modifiers: [.command, .shift]),
                .separator(),
                MenuItem.make("Cut", #selector(NSText.cut(_:)), key: "x"),
                MenuItem.make("Copy", #selector(NSText.copy(_:)), key: "c"),
                MenuItem.make("Paste", #selector(NSText.paste(_:)), key: "v"),
                MenuItem.make("Delete", #selector(NSText.delete(_:))),
                MenuItem.make("Select All", #selector(NSText.selectAll(_:)), key: "a"),
                MenuItem.make(
                    "Move Item Here", #selector(Window.moveItemHere(_:)), key: "v",
                    modifiers: [.command, .option]),
                MenuItem.make(
                    "Move to Trash", #selector(Window.moveSelectionToTrash(_:)), key: "\u{8}"),
                .separator(),
                moveTo(fillers[0]),
                moveTo(fillers[1]),
                MenuItem.make("Copy to Other Window", #selector(Window.copyToOtherWindow(_:))),
                MenuItem.make("Move to Other Window", #selector(Window.moveToOtherWindow(_:))),
                .separator(),
                MenuItem.make("Find", #selector(Window.findInFolder(_:)), key: "f"),
                .separator(),
                spelling(),
            ])
    }

    /// What fills Move to ▸ and Copy to ▸ for the window in front (ADR 0147), kept as long as
    /// the menu, which holds its delegate weakly.
    private static let fillers = [MoveToMenuFiller(.move), MoveToMenuFiller(.copy)]

    private static func moveTo(_ filler: MoveToMenuFiller) -> NSMenuItem {
        let item = NSMenuItem(title: filler.title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: filler.title)
        menu.delegate = filler
        item.submenu = menu
        return item
    }

    /// AppKit's own checking of the text being edited, and whether a name shows its
    /// misspelled words while it is typed. A name is never corrected automatically: the
    /// user picks each correction.
    private static func spelling() -> NSMenuItem {
        MenuItem.menu(
            "Spelling and Grammar",
            [
                MenuItem.make(
                    "Show Spelling and Grammar", #selector(NSText.showGuessPanel(_:)), key: ":"),
                MenuItem.make("Check Document Now", #selector(NSText.checkSpelling(_:)), key: ";"),
                .separator(),
                MenuItem.make(
                    "Check Spelling While Typing",
                    #selector(Window.toggleSpellingWhileTyping(_:))),
            ])
    }
}
