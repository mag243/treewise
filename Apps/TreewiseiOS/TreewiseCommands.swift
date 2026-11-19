import SwiftUI
import TreewiseCore
import TreewiseUI
import UIKit

/// The menus' commands with the Mac's keys (ADR 0135), in the menu bar from iPadOS 26 and in
/// the list holding ⌘ shows before. They act on the window in front; the list's commands are
/// sent down the responder chain to the folder's collection view, so they act only while
/// the list has the keyboard, and Cut, Copy, Paste, Select All, Undo and Redo are the
/// system's own.
struct TreewiseCommands: Commands {
    @FocusedValue(\.browserWindow) private var window: BrowserWindow?
    @Environment(\.openWindow) private var openWindow

    private var browser: BrowserState? { window?.browser }
    /// The window's browser, while the window shows no sheet; asked as a command runs, as
    /// the menus are not drawn again for every change of the window (ADR 0135).
    private var acting: BrowserState? { window?.isPresenting == false ? browser : nil }

    var body: some Commands {
        CommandGroup(replacing: .newItem) { fileCommands }
        CommandGroup(after: .pasteboard) { editCommands }
        CommandMenu("Go") { goCommands }
    }

    @ViewBuilder private var fileCommands: some View {
        Button("New Window") {
            openWindow(value: WindowRequest(showing: browser?.snapshot))
        }
        .keyboardShortcut("n")
        Button("New Folder") {
            if acting?.canAddItems == true { window?.newFolder?() }
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        .disabled(window == nil)
        Divider()
        Button("Open") { send(#selector(FolderCollectionView.openSelection(_:))) }
            .keyboardShortcut(.downArrow)
            .disabled(window == nil)
        Button("Open in New Window") {
            send(#selector(FolderCollectionView.openSelectionInNewWindow(_:)))
        }
        .keyboardShortcut(.downArrow, modifiers: [.command, .option])
        .disabled(window == nil)
        Button("Rename") { send(#selector(FolderCollectionView.renameSelection(_:))) }
            .disabled(window == nil)
    }

    @ViewBuilder private var editCommands: some View {
        Button("Move Item Here") { send(#selector(FolderCollectionView.moveItemHere(_:))) }
            .keyboardShortcut("v", modifiers: [.command, .option])
            .disabled(window == nil)
        Button("Move to Trash") {
            send(#selector(FolderCollectionView.moveSelectionToTrash(_:)))
        }
        .keyboardShortcut(.delete)
        .disabled(window == nil)
    }

    @ViewBuilder private var goCommands: some View {
        Button("Back") {
            guard let browser = acting else { return }
            Task { await browser.goBack(pane: 0) }
        }
        .keyboardShortcut("[")
        .disabled(window == nil)
        Button("Forward") {
            guard let browser = acting else { return }
            Task { await browser.goForward(pane: 0) }
        }
        .keyboardShortcut("]")
        .disabled(window == nil)
        Button("Enclosing Folder") {
            guard let browser = acting else { return }
            Task { await browser.goUp(pane: 0) }
        }
        .keyboardShortcut(.upArrow)
        .disabled(window == nil)
    }

    /// Sends a list's command to the first responder: the folder's collection view while
    /// the list has the keyboard.
    private func send(_ action: Selector) {
        UIApplication.shared.sendAction(action, to: nil, from: nil, for: nil)
    }
}

extension FocusedValues {
    /// The window in front, which the menus' commands act on (ADR 0135).
    @Entry var browserWindow: BrowserWindow?
}
