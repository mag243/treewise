import QuickLook
import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder the browser shows: its path above its table, with Back, Forward
/// and Enclosing Folder. Opening
/// a folder goes into it; opening a file shows it in Quick Look.
struct FolderView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.locale) private var locale
    /// The file Quick Look shows, if any.
    @State private var previewed: URL?
    /// Whether the user is selecting, when a tap selects instead of opening (ADR 0124).
    @State private var isSelecting = false

    let browser: BrowserState
    let settings: BrowserSettings
    let locations: Locations

    private var conflicts: ConflictQuestions { locations.conflicts }
    private var undoManager: UndoManager { locations.undo.manager }

    private var tab: TabModel { browser.layout.focusedPane.activeTab }
    private var content: TreewiseUI.TabContent { browser.content(of: tab.id) }
    private var items: [FileItem] { browser.visibleItems(of: tab.id) }

    var body: some View {
        VStack(spacing: 0) {
            PathBar(browser: browser, folder: tab.folder, drops: drops)
            Divider()
            list
                .allowsHitTesting(!isReading)
                .overlay { placeholder }
        }
        .navigationTitle(isSelecting ? selectedTitle : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .searchable(
            text: Binding(
                get: { content.query },
                set: { browser.setQuery($0, in: tab.id) })
        )
        .refreshable { await browser.refresh(pane: 0) }
        .onChange(of: tab.folder) { isSelecting = false }
        .onChange(of: isSelecting) {
            if !isSelecting { browser.setSelection([], in: tab.id) }
        }
        .safeAreaInset(edge: .bottom) {
            ProgressBar(browser: browser, isAsking: conflicts.question != nil)
        }
        .quickLookPreview($previewed, in: previewableFiles)
        .modifier(RenameAlert(browser: browser, undoManager: undoManager))
        .sheet(isPresented: isAskingAboutConflict) {
            if let question = conflicts.question {
                ConflictSheet(questions: conflicts, name: question.name)
            }
        }
        .alert(
            failureText, isPresented: isShowingFailure
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    private var drops: ItemDrops {
        ItemDrops(browser: browser, locations: locations, undoManager: undoManager)
    }

    private var actions: ItemActions {
        ItemActions(browser: browser, conflicts: conflicts, undoManager: undoManager, open: open)
    }

    private var isAskingAboutConflict: Binding<Bool> {
        Binding(
            get: { conflicts.question != nil },
            set: { if !$0 { conflicts.answer(.stop, appliesToAll: false) } })
    }

    /// Why the last operation failed, as the Mac says it.
    private var failureText: String {
        browser.failure.map { FailureMessage.text(for: $0, locale: locale) } ?? ""
    }

    private var isShowingFailure: Binding<Bool> {
        Binding(get: { browser.failure != nil }, set: { if !$0 { browser.clearFailure() } })
    }

    private var list: some View {
        FolderTable(
            browser: browser, items: items, folder: content.folder, settings: settings,
            actions: actions, drops: drops, isCompact: sizeClass == .compact,
            isSelecting: $isSelecting)
    }

    /// Whether the folder just opened is still being read; the list then still holds the
    /// folder left (ADR 0121).
    private var isReading: Bool { browser.isReading(tab.id) }

    /// How many items are selected, while the user selects.
    private var selectedTitle: String {
        String(localized: "\(content.selection.count) Selected")
    }

    /// The folder's name, from the path while it is being read.
    private var title: String {
        isReading ? PathBar.name(of: tab.folder, in: browser) : content.folder?.name ?? ""
    }

    @ViewBuilder private var placeholder: some View {
        if isReading {
            ReadingPlaceholder(name: title)
        } else if let failure = content.failure {
            ContentUnavailableView(
                FailureMessage.text(for: failure, locale: locale),
                systemImage: "exclamationmark.triangle")
        } else if items.isEmpty, content.folder != nil {
            ContentUnavailableView(
                ListPlaceholder.text(query: content.query, locale: locale),
                systemImage: "folder")
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                Task { await browser.goBack(pane: 0) }
            } label: {
                Label("Back", systemImage: "chevron.backward")
            }
            .disabled(!tab.history.canGoBack)
            Button {
                Task { await browser.goForward(pane: 0) }
            } label: {
                Label("Forward", systemImage: "chevron.forward")
            }
            .disabled(!tab.history.canGoForward)
            Button {
                Task { await browser.goUp(pane: 0) }
            } label: {
                Label("Enclosing Folder", systemImage: "arrow.up")
            }
            .disabled(!browser.canGoUp(pane: 0))
            Button(action: locations.undo.undo) {
                Label(locations.undo.undoTitle, systemImage: "arrow.uturn.backward")
            }
            .disabled(!locations.undo.canUndo)
            // The UI tests find it by it.
            .accessibilityIdentifier("undo")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if isSelecting {
                SelectionButtons(
                    browser: browser, actions: actions, items: items, isSelecting: $isSelecting)
            } else {
                Button(action: actions.paste) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .disabled(!actions.canPaste)
                Button(action: actions.newFolder) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .disabled(!actions.canAddItems)
                ViewMenu(browser: browser, settings: settings)
                Button("Select") { isSelecting = true }
                    .disabled(items.isEmpty)
            }
        }
    }

    /// The files of the folder, for Quick Look to page through.
    private var previewableFiles: [URL] {
        items.filter { !$0.isContainer }.map { URL(fileURLWithPath: $0.id.rawValue) }
    }

    private func open(_ item: FileItem) {
        if item.isContainer {
            Task { await browser.navigate(pane: 0, to: item.id) }
        } else {
            previewed = URL(fileURLWithPath: item.id.rawValue)
        }
    }
}
