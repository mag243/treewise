import AppKit

/// Building menu items (ADR 0081): a title from the String Catalog, an action
/// that goes through the responder chain unless a target is given, and a key.
@MainActor
enum MenuItem {
    static func make(
        _ title: String.LocalizationValue, _ action: Selector?, key: String = "",
        modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: title), action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        return item
    }

    /// A menu with these items, under its title in the menu bar.
    static func menu(_ title: String.LocalizationValue, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: String(localized: title))
        menu.items = items
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    /// The key of an arrow, as a menu item's key equivalent.
    static func arrow(_ key: Int) -> String {
        String(Character(UnicodeScalar(UInt16(key)) ?? " "))
    }
}
