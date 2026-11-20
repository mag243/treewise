import XCTest

extension XCUIElementTypeQueryProvider {
    /// The item `title` in the submenu `submenu` of this menu, the submenu opened by moving
    /// the pointer onto it, as the context menu groups its subjects (ADR 0142).
    @MainActor
    func submenuItem(_ title: String, in submenu: String) -> XCUIElement {
        let parent = menuItems[submenu]
        parent.hover()
        return parent.menuItems[title]
    }
}
