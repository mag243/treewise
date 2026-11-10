import AppKit
import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// The address bar while a path is typed (M5b), an AppKit text field (ADR
/// 0081): it starts with the folder's path and takes the focus, suggests
/// folder names as they are typed (`TypedPath`), goes there on Return and
/// stops on Escape or when it loses the focus. A path that names no folder
/// inside the boundary (ADR 0019) is refused with a message.
struct AddressField: NSViewRepresentable {
    let browser: BrowserState
    let paneIndex: Int
    let folder: FileItem.ID
    /// Ends editing, with or without going anywhere.
    let done: () -> Void

    func makeCoordinator() -> AddressFieldCoordinator {
        AddressFieldCoordinator(browser: browser, paneIndex: paneIndex, folder: folder, done: done)
    }

    func makeNSView(context: Context) -> FocusingTextField {
        let field = FocusingTextField(string: folder.shownPath)
        field.bezelStyle = .roundedBezel
        field.placeholderString = String(localized: "Address")
        field.setAccessibilityLabel(String(localized: "Address"))
        field.lineBreakMode = .byTruncatingHead
        field.delegate = context.coordinator
        field.suggestionsDelegate = context.coordinator
        return field
    }

    func updateNSView(_ field: FocusingTextField, context: Context) {}
}

/// A text field that takes the keyboard focus once it is in a window, and
/// gives the window the path's whole text selected.
final class FocusingTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.makeFirstResponder(self)
        currentEditor()?.selectAll(nil)
    }
}

/// What the address field does with its text: going, stopping and suggesting.
@MainActor
final class AddressFieldCoordinator: NSObject, NSTextFieldDelegate, NSTextSuggestionsDelegate {
    typealias SuggestionItemType = String

    private let browser: BrowserState
    private let paneIndex: Int
    private let folder: FileItem.ID
    private let done: () -> Void
    /// The names of the folders in the folder being completed, read once per folder.
    private var names: (folder: String, names: [String])?
    /// Whether a refusal is shown, during which losing the focus does not stop.
    private var isRefusing = false
    private var hasEnded = false

    init(browser: BrowserState, paneIndex: Int, folder: FileItem.ID, done: @escaping () -> Void) {
        self.browser = browser
        self.paneIndex = paneIndex
        self.folder = folder
        self.done = done
    }

    private var home: String { LaunchOptions.homeFolder.path }

    // MARK: - Going and stopping

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector)
        -> Bool
    {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            go(control.stringValue, in: control.window)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            end()
            return true
        default:
            return false
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if !isRefusing { end() }
    }

    private func go(_ text: String, in window: NSWindow?) {
        guard text != folder.shownPath else { return end() }
        let reader = LocalFileSystem(locations: LaunchOptions.locations)
        guard let path = TypedPath.resolve(text, home: home, current: folder.shownPath),
            (try? reader.currentItem(at: FileItem.ID(path)))?.isContainer == true
        else { return refuse(text, in: window) }
        end()
        let browser = browser
        let pane = paneIndex
        Task { await browser.navigate(pane: pane, to: FileItem.ID(path)) }
    }

    private func end() {
        guard !hasEnded else { return }
        hasEnded = true
        done()
    }

    /// Says the text names no folder, in a sheet, and lets the user change it.
    private func refuse(_ text: String, in window: NSWindow?) {
        guard let window else { return }
        isRefusing = true
        let field = window.firstResponder
        let alert = NSAlert()
        alert.messageText = String(
            localized: "Treewise can’t find “\(text)”. Check the spelling and try again.")
        alert.beginSheetModal(for: window) { [weak self] _ in
            self?.isRefusing = false
            if let field { window.makeFirstResponder(field) }
        }
    }

    // MARK: - Suggesting

    func textField(
        _ textField: NSTextField,
        provideUpdatedSuggestions responseHandler: @escaping (ItemResponse) -> Void
    ) {
        let text = textField.stringValue
        guard
            let parent = TypedPath.completionFolder(
                for: text, home: home, current: folder.shownPath)
        else { return responseHandler(ItemResponse(items: [])) }
        if let names, names.folder == parent {
            return responseHandler(response(for: text, in: parent, names.names))
        }
        let browser = browser
        Task {
            let read = await browser.subfolders(of: FileItem.ID(parent)).map(\.name)
            names = (parent, read)
            responseHandler(response(for: text, in: parent, read))
        }
    }

    func textField(_ textField: NSTextField, textCompletionFor item: Item) -> String? {
        item.representedValue + "/"
    }

    private func response(for text: String, in parent: String, _ names: [String]) -> ItemResponse {
        let completions = TypedPath.completions(
            for: text, home: home, current: folder.shownPath
        ) { $0 == parent ? names : [] }
        return ItemResponse(items: completions.map { Item(representedValue: $0, title: $0) })
    }
}
