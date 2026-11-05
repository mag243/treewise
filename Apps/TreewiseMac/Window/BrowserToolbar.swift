import SwiftUI
import TreewiseUI

/// Back, Forward, Enclosing Folder and Refresh for the window's folder (ADR
/// 0037); the address bar is a row of the window and the actions are in the
/// command bar. The toolbar is not
/// customizable: SwiftUI's customizable toolbar crashes when a second window
/// opens, in NSToolbar's sync between the windows' toolbars.
struct BrowserToolbar: ToolbarContent {
    let browser: BrowserState
    let undoManager: UndoManager?

    var body: some ToolbarContent {
        let pane = browser.layout.focusedPaneIndex
        let history = browser.layout.focusedPane.activeTab.history
        ToolbarItem(placement: .navigation) {
            Button("Back", systemImage: "chevron.left") {
                Task { await browser.goBack(pane: pane) }
            }
            .disabled(!history.canGoBack)
            .keyboardShortcut("[", modifiers: .command)
        }
        ToolbarItem(placement: .navigation) {
            Button("Forward", systemImage: "chevron.right") {
                Task { await browser.goForward(pane: pane) }
            }
            .disabled(!history.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
        }
        ToolbarItem(placement: .navigation) {
            Button("Enclosing Folder", systemImage: "arrow.up") {
                Task { await browser.goUp(pane: pane) }
            }
            .disabled(!browser.canGoUp(pane: pane))
            .keyboardShortcut(.upArrow, modifiers: .command)
        }
        ToolbarItem(placement: .navigation) {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await browser.refresh(pane: pane) }
            }
            .help(Text("Read the folder again"))
            .keyboardShortcut("r", modifiers: .command)
        }
    }
}
