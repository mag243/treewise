import QuickLook
import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder the browser shows: its path above its table, with Back, Forward
/// and Enclosing Folder; where the width is compact, as on the iPhone, Files' layout
/// instead (ADR 0132). Opening a folder goes into it; opening a file shows it in Quick Look.
struct FolderView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.locale) private var locale
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow
    /// The file Quick Look shows, if any.
    @State private var previewed: URL?
    /// Whether the user is selecting, when a tap selects instead of opening (ADR 0124).
    @State private var isSelecting = false
    /// The name overview shown, if any (ADR 0129).
    @State private var review: NameReviewShown?
    /// The name asked for, if any: a rename, or a new folder's (ADR 0130).
    @State private var naming: NameSheetRequest?
    /// The folder asked for to move or copy items to, if any (ADR 0132).
    @State private var movingTo: MoveToRequest?
    /// The items offered to the share sheet, if any (ADR 0132).
    @State private var sharing: ShareRequest?
    /// What Folder Structure ▸ asked for, if anything (ADR 0091).
    @State private var structureAsked = FolderStructureAsked()
    /// Whether the search field has the keyboard, which Find gives it (ADR 0135).
    @FocusState private var isSearchFocused: Bool

    let browser: BrowserState
    let settings: BrowserSettings
    let locations: Locations
    let window: BrowserWindow

    private var conflicts: ConflictQuestions { window.conflicts }
    private var undoManager: UndoManager { locations.undo.manager }

    private var tab: TabModel { browser.layout.focusedPane.activeTab }
    private var content: TreewiseUI.TabContent { browser.content(of: tab.id) }
    private var items: [FileItem] { browser.visibleItems(of: tab.id) }

    var body: some View {
        VStack(spacing: 0) {
            if !isCompact {
                PathBar(browser: browser, folder: tab.folder, drops: drops)
                Divider()
            }
            list
                .allowsHitTesting(!isReading)
                .overlay { placeholder }
        }
        .navigationTitle(isSelecting ? selectedTitle : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .modifier(EnclosingFolderButton.TitleMenu(browser: browser, isShown: isCompact))
        // The enclosing folder takes the back button's place below a location's top, as
        // the button that selects every item does while the user selects.
        .navigationBarBackButtonHidden(
            isCompact
                && (isSelecting || !EnclosingFolderButton.enclosing(in: browser).isEmpty)
        )
        .searchable(
            text: Binding(
                get: { content.query },
                set: { browser.setQuery($0, in: tab.id) })
        )
        .searchFocused($isSearchFocused)
        .onChange(of: window.findRequests) {
            isSearchFocused = true
        }
        .refreshable { await browser.refresh(pane: 0) }
        .onChange(of: isPresenting, initial: true) { window.isFolderPresenting = isPresenting }
        .onAppear { window.newFolder = { actions.newFolder() } }
        .onChange(of: tab.folder) { isSelecting = false }
        .onChange(of: isSelecting) {
            if !isSelecting { browser.setSelection([], in: tab.id) }
        }
        .safeAreaInset(edge: .bottom) {
            ProgressBar(browser: browser, isAsking: conflicts.question != nil)
        }
        .quickLookPreview($previewed, in: previewableFiles)
        .onChange(of: browser.renameRequest, initial: true) { askNameForRenameRequest() }
        .sheet(item: $naming) { request in
            NameSheet(
                request: request, browser: browser, undoManager: undoManager,
                openOverview: { actions.suggestNames(for: [$0]) })
        }
        .sheet(item: $movingTo) { request in
            MoveToSheet(request: request, browser: browser, drops: drops)
        }
        .sheet(item: $sharing) { request in
            ShareSheet(request: request)
                .presentationDetents([.medium, .large])
        }
        .modifier(
            FolderStructureSheets(
                asked: structureAsked, browser: browser, undoManager: undoManager,
                folders: items.filter { $0.kind == .folder }.map(\.id))
        )
        .sheet(isPresented: isAskingAboutConflict) {
            if let question = conflicts.question {
                ConflictSheet(questions: conflicts, name: question.name)
            }
        }
        .modifier(PermanentDeleteAlert(browser: browser, failureText: failureText))
        .fullScreenCover(item: $review) { shown in
            NameReviewSheet(
                model: shown.model, browser: browser, settings: settings,
                undoManager: undoManager)
        }
    }

    private var drops: ItemDrops {
        ItemDrops(
            browser: browser, locations: locations, window: window, undoManager: undoManager)
    }

    private var actions: ItemActions {
        ItemActions(
            browser: browser, conflicts: conflicts, undoManager: undoManager, open: open,
            suggestNames: suggestNames, askName: { naming = $0 },
            moveTo: isCompact ? { movingTo = $0 } : nil,
            share: isCompact ? { sharing = ShareRequest(items: $0) } : nil,
            openInNewWindow: supportsMultipleWindows ? { openInNewWindow($0) } : nil,
            folderStructure: { structureAsked.ask($0, browser: browser) })
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

    private var list: some View {
        FolderTable(
            browser: browser, items: items, folder: content.folder, settings: settings,
            actions: actions, drops: drops, isCompact: isCompact,
            isSelecting: $isSelecting, isPresenting: window.isPresenting,
            find: { window.findRequests += 1 },
            toggleSidebar: {
                window.columnVisibility =
                    window.columnVisibility == .detailOnly ? .all : .detailOnly
            })
    }

    /// Whether the folder view shows a sheet, an alert or Quick Look (ADR 0135).
    private var isPresenting: Bool {
        naming != nil || review != nil || movingTo != nil || sharing != nil || previewed != nil
            || browser.failure != nil
    }

    /// Whether the width is compact, as on the iPhone (ADR 0132).
    private var isCompact: Bool { sizeClass == .compact }

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
        if browser.isReadingSlowly(tab.id) {
            ReadingPlaceholder(name: title)
        } else if isReading {
            EmptyView()
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
        if isCompact {
            CompactFolderToolbar(
                browser: browser, settings: settings, undo: locations.undo, actions: actions,
                items: items, isSelecting: $isSelecting)
        } else {
            regularToolbar
        }
    }

    @ToolbarContentBuilder private var regularToolbar: some ToolbarContent {
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
            // A tap undoes; a long press offers Redo, as in Pages (ADR 0125).
            Menu {
                Button(action: locations.undo.redo) {
                    Label(locations.undo.redoTitle, systemImage: "arrow.uturn.forward")
                }
                .disabled(!locations.undo.canRedo)
            } label: {
                Label(locations.undo.undoTitle, systemImage: "arrow.uturn.backward")
            } primaryAction: {
                locations.undo.undo()
            }
            .disabled(!locations.undo.canUndo && !locations.undo.canRedo)
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
                ViewMenu(browser: browser, settings: settings, actions: actions)
                Button("Select") { isSelecting = true }
                    .disabled(items.isEmpty)
            }
        }
    }

    /// Opens `folder` in a new window, with this window's sort order and view (ADR 0134).
    private func openInNewWindow(_ folder: FileItem) {
        openWindow(
            value: WindowRequest(showing: browser.snapshot.showing(folder.id)))
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

    /// Asks for the name of the item `BrowserState.renameRequest` names, found among all
    /// the folder's items, as a search may hide it.
    private func askNameForRenameRequest() {
        guard let item = browser.renameTarget else { return }
        naming = NameSheetRequest(
            purpose: .rename(item), name: item.name, suggests: browser.renameSuggests)
        browser.renameRequest = nil
        browser.renameSuggests = false
    }

    /// Opens the name overview of the selection, or of the folder's files.
    private func suggestNames(wholeFolder: Bool) {
        Task {
            let host = NameServices.moduleHost
            let store = NameServices.folderSettings
            let made =
                wholeFolder
                ? await browser.makeFolderNameReview(host: host, store: store)
                : await browser.makeNameReview(host: host, store: store)
            guard let made else { return }
            review = NameReviewShown(model: made)
            await made.start()
        }
    }
}
