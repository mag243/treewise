import QuickLook
import SwiftUI
import TreewiseCore
import TreewiseUI

/// The folder the browser shows: its path above a table on a wide screen or
/// a list on a narrow one, with Back, Forward and Enclosing Folder. Opening
/// a folder goes into it; opening a file shows it in Quick Look.
struct FolderView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.locale) private var locale
    @Environment(\.undoManager) private var undoManager
    @State private var conflicts = ConflictQuestions()
    /// The file Quick Look shows, if any.
    @State private var previewed: URL?

    let browser: BrowserState
    let settings: BrowserSettings

    private var tab: TabModel { browser.layout.focusedPane.activeTab }
    private var content: TreewiseUI.TabContent { browser.content(of: tab.id) }
    private var items: [FileItem] { browser.visibleItems(of: tab.id) }

    var body: some View {
        VStack(spacing: 0) {
            PathBar(browser: browser, folder: tab.folder)
            Divider()
            list
                .overlay { placeholder }
        }
        .navigationTitle(content.folder?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .searchable(
            text: Binding(
                get: { content.query },
                set: { browser.setQuery($0, in: tab.id) })
        )
        .refreshable { await browser.refresh(pane: 0) }
        .safeAreaInset(edge: .bottom) { ProgressBar(browser: browser) }
        .quickLookPreview($previewed, in: previewableFiles)
        .modifier(RenameAlert(browser: browser, items: items, undoManager: undoManager))
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

    @ViewBuilder private var list: some View {
        if sizeClass == .compact {
            FolderList(browser: browser, items: items, settings: settings, actions: actions)
        } else {
            FolderTable(browser: browser, items: items, settings: settings, actions: actions)
        }
    }

    @ViewBuilder private var placeholder: some View {
        if let failure = content.failure {
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
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: actions.paste) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .disabled(!actions.canPaste)
            Button(action: actions.newFolder) {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .disabled(!actions.canAddItems)
            ViewMenu(browser: browser, settings: settings)
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
