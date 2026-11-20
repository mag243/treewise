import AppKit

/// Finds two items of the menu bar that share a key (ADR 0142): AppKit then runs whichever
/// it finds first, so one of them can never be reached by its key.
@MainActor
enum MenuKeyCheck {
    /// The keys, as `⌥⌘n`, that more than one item of `menu` and its submenus has, with the
    /// titles of those items.
    static func shared(in menu: NSMenu) -> [String: [String]] {
        var titles: [String: [String]] = [:]
        collect(menu, into: &titles)
        return titles.filter { $0.value.count > 1 }
    }

    private static func collect(_ menu: NSMenu, into titles: inout [String: [String]]) {
        for item in menu.items {
            if let submenu = item.submenu { collect(submenu, into: &titles) }
            guard !item.keyEquivalent.isEmpty else { continue }
            titles[name(of: item), default: []].append(item.title)
        }
    }

    private static func name(of item: NSMenuItem) -> String {
        let flags = item.keyEquivalentModifierMask
        let marks: [(NSEvent.ModifierFlags, String)] = [
            (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘"),
        ]
        return marks.filter { flags.contains($0.0) }.map(\.1).joined()
            + item.keyEquivalent.lowercased()
    }
}
