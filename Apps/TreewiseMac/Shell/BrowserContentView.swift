import SwiftUI
import TreewiseUI

/// The folder side of a browser window: the address bar, the command bar, the
/// folder and the details pane, with the progress of a transfer over them.
struct BrowserContentView: View {
    let browser: BrowserState
    @Bindable var model: WindowModel
    /// Opens a window beside this one (⌥⌘N).
    let windowBeside: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AddressRow(browser: browser, isEditing: $model.isEditingAddress)
            Divider()
            CommandBar(
                browser: browser, undoManager: SharedUndo.manager, windowBeside: windowBeside)
            Divider()
            HStack(spacing: 0) {
                PaneView(browser: browser, paneIndex: browser.layout.focusedPaneIndex)
                if browser.settings.showsDetails {
                    Divider()
                    DetailsPane(browser: browser)
                }
            }
        }
        .overlay(alignment: .bottom) {
            OperationProgressView(browser: browser)
        }
    }
}
