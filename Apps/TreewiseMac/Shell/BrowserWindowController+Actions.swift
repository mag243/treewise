import AppKit
import TreewiseCore
import TreewiseUI

/// The menu bar's and the toolbar's actions for a browser window (ADR 0022,
/// ADR 0081). AppKit asks `validateMenuItem(_:)` and `validateToolbarItem(_:)`
/// whether each can be chosen just before a menu opens, a key is pressed or
/// the toolbar is drawn, so nothing is rebuilt while a menu is open.
extension BrowserWindowController: NSMenuItemValidation, NSToolbarItemValidation {
    // MARK: File

    /// File > New Tab (⌘T) and the + button of the tab bar.
    override func newWindowForTab(_ sender: Any?) { actions.newTab() }
    @objc func newFolder(_ sender: Any?) { actions.newFolder() }
    @objc func openSelection(_ sender: Any?) { actions.openSelection(option: false) }
    @objc func openSelectionInOtherWindow(_ sender: Any?) { actions.openSelection(option: true) }
    @objc func suggestNames(_ sender: Any?) { actions.suggestNames() }
    @objc func suggestNamesForFolder(_ sender: Any?) { actions.suggestNamesForFolder() }
    @objc func extractAll(_ sender: Any?) { actions.archives.extract() }
    @objc func compressToZip(_ sender: Any?) { actions.archives.compress(to: .zip) }
    @objc func compressTo7z(_ sender: Any?) { actions.archives.compress(to: .sevenZip) }
    @objc func compressToTarGz(_ sender: Any?) { actions.archives.compress(to: .tarGzip) }
    @objc func renameSelection(_ sender: Any?) { actions.rename() }
    @objc func renameWithSuggestions(_ sender: Any?) { actions.renameWithSuggestions() }
    @objc func ejectSelection(_ sender: Any?) { actions.eject() }
    @objc func openInTerminal(_ sender: Any?) { actions.openTerminal() }
    @objc func goToAddress(_ sender: Any?) { actions.editAddress() }

    // MARK: Edit

    @objc func moveItemHere(_ sender: Any?) { actions.moveHere() }
    @objc func moveSelectionToTrash(_ sender: Any?) { actions.moveToTrash() }
    @objc func copyToOtherWindow(_ sender: Any?) { actions.sendToOtherWindow(.copy) }
    @objc func moveToOtherWindow(_ sender: Any?) { actions.sendToOtherWindow(.move) }
    @objc func findInFolder(_ sender: Any?) { actions.focusSearch() }
    @objc func toggleSpellingWhileTyping(_ sender: Any?) { actions.toggleSpellingWhileTyping() }

    // MARK: View

    @objc func showAsIcons(_ sender: Any?) { actions.show(.icons) }
    @objc func showAsList(_ sender: Any?) { actions.show(.list) }
    @objc func toggleDetails(_ sender: Any?) { actions.toggleDetails() }
    @objc func refreshFolder(_ sender: Any?) {
        let pane = browser.layout.focusedPaneIndex
        Task { await browser.refresh(pane: pane) }
    }

    // MARK: Go

    @objc func goBack(_ sender: Any?) {
        let pane = browser.layout.focusedPaneIndex
        Task { await browser.goBack(pane: pane) }
    }

    @objc func goForward(_ sender: Any?) {
        let pane = browser.layout.focusedPaneIndex
        Task { await browser.goForward(pane: pane) }
    }

    @objc func goToEnclosingFolder(_ sender: Any?) {
        let pane = browser.layout.focusedPaneIndex
        Task { await browser.goUp(pane: pane) }
    }

    // MARK: Window

    @objc func windowBeside(_ sender: Any?) { actions.windowBeside() }
    @objc func tileWithOtherWindow(_ sender: Any?) { actions.tileWithOtherWindow() }

    // MARK: Validation

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleDetails(_:)) {
            item.title =
                actions.showsDetails
                ? String(localized: "Hide Details") : String(localized: "Show Details")
        }
        if item.action == #selector(toggleSpellingWhileTyping(_:)) {
            item.state = actions.checksSpellingWhileTyping ? .on : .off
        }
        return item.action.map(canPerform) ?? false
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        item.action.map(canPerform) ?? false
    }

    /// Whether the action of a menu or toolbar item can be done now.
    private func canPerform(_ action: Selector) -> Bool {
        if let rule = Self.fileRules[action] ?? Self.editRules[action] ?? Self.goRules[action] {
            return rule(actions)
        }
        return responds(to: action)
    }

    private typealias Rule = @MainActor (BrowserActions) -> Bool

    private static let fileRules: [Selector: Rule] = [
        #selector(newWindowForTab(_:)): { $0.canArrange },
        #selector(newFolder(_:)): { $0.canAddItems },
        #selector(openSelection(_:)): { $0.hasSelection },
        #selector(openSelectionInOtherWindow(_:)): { $0.hasSelection },
        #selector(suggestNames(_:)): { $0.canSuggestNames },
        #selector(suggestNamesForFolder(_:)): { $0.canSuggestNames },
        #selector(extractAll(_:)): { $0.canExtract },
        #selector(compressToZip(_:)): { $0.canCompress },
        #selector(compressTo7z(_:)): { $0.canCompress },
        #selector(compressToTarGz(_:)): { $0.canCompress },
        #selector(renameSelection(_:)): { $0.canRename },
        #selector(renameWithSuggestions(_:)): { $0.canRenameWithSuggestions },
        #selector(ejectSelection(_:)): { !$0.ejectableSelection.isEmpty },
        #selector(openInTerminal(_:)): { $0.canOpenTerminal },
    ]

    private static let editRules: [Selector: Rule] = [
        #selector(moveItemHere(_:)): { $0.canMoveHere },
        #selector(moveSelectionToTrash(_:)): { $0.canTrash },
        #selector(copyToOtherWindow(_:)): { $0.canSendToOtherWindow },
        #selector(moveToOtherWindow(_:)): { $0.canMoveToOtherWindow },
        #selector(windowBeside(_:)): { $0.canArrange },
        #selector(tileWithOtherWindow(_:)): { $0.canArrange },
    ]

    private static let goRules: [Selector: Rule] = [
        #selector(goBack(_:)): { $0.browser.layout.focusedPane.activeTab.history.canGoBack },
        #selector(goForward(_:)): {
            $0.browser.layout.focusedPane.activeTab.history.canGoForward
        },
        #selector(goToEnclosingFolder(_:)): {
            $0.browser.canGoUp(pane: $0.browser.layout.focusedPaneIndex)
        },
    ]
}
