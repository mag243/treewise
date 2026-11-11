import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// The window's folder: its list or icons, with a message over them when the
/// folder is empty or cannot be read, and the status bar with the view
/// buttons.
@MainActor
final class PaneController: NSViewController {
    private static let messagePadding: CGFloat = 20

    let browser: BrowserState
    private let folderArea = NSView()
    private let message = NSTextField(wrappingLabelWithString: "")
    private lazy var statusBar = PaneStatusBar { [weak self] mode in
        self?.browser.viewMode = mode
    }
    private let list = FileTableCoordinator()
    private let grid = FileGridCoordinator()
    private lazy var listView = list.makeScrollView()
    private lazy var gridView = grid.makeScrollView()
    /// The downloads running among the files shown, with their fractions done (ADR 0051).
    private var downloads: [FileItem.ID: Double] = [:]
    /// The files kept only online whose downloads are followed.
    private var followed: [FileItem.ID]?
    private var following: Task<Void, Never>?

    /// The pane the window shows: a window has one (ADR 0037).
    var paneIndex: Int { browser.layout.focusedPaneIndex }

    init(browser: BrowserState) {
        self.browser = browser
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        message.alignment = .center
        message.isSelectable = false
        let rows = NSStackView(views: [folderArea, Self.separator(), statusBar])
        rows.orientation = .vertical
        rows.spacing = 0
        rows.alignment = .leading
        for row in rows.arrangedSubviews {
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        folderArea.setContentHuggingPriority(.defaultLow, for: .vertical)
        view = rows
        Observing.follow(self) { $0.update() }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        update()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        following?.cancel()
        following = nil
        followed = nil
    }

    private func update() {
        // Observation can bring a change once more after the pane is gone.
        guard let pane = browser.layout.pane(at: paneIndex) else { return }
        let tab = pane.activeTabID
        let content = browser.content(of: tab)
        let items = browser.visibleItems(of: tab)
        if view.window != nil { followDownloads(of: items.filter(\.isOnlyOnline).map(\.id)) }
        showFolder(content: content, items: items, tab: tab)
        showMessage(content: content, isEmpty: items.isEmpty)
        statusBar.show(counts: statusText(items: items, content: content), mode: browser.viewMode)
    }

    // MARK: - The folder

    private func showFolder(content: TreewiseUI.TabContent, items: [FileItem], tab: TabModel.ID) {
        let isActive = browser.layout.focusedPaneIndex == paneIndex
        let renameRequest = isActive ? browser.renameRequest : nil
        let revealRequest = isActive ? browser.revealRequest : nil
        let actions = actions(for: tab)
        switch browser.viewMode {
        case .list:
            show(listView)
            list.update(
                with: FileTableContent(
                    folder: content.folder, items: items, selection: content.selection,
                    sort: browser.sort, isActive: isActive, cutItems: cutItems,
                    renameRequest: renameRequest, revealRequest: revealRequest,
                    downloads: downloads, showsExtensions: browser.settings.showsExtensions,
                    rowHeight: browser.settings.rowDensity.rowHeight, actions: actions))
        case .icons:
            show(gridView)
            grid.update(
                with: FileGridContent(
                    folder: content.folder, items: items, selection: content.selection,
                    isActive: isActive, cutItems: cutItems, renameRequest: renameRequest,
                    revealRequest: revealRequest, downloads: downloads,
                    showsExtensions: browser.settings.showsExtensions, actions: actions))
        }
    }

    /// Puts `folderView` in the folder's place, under the message.
    private func show(_ folderView: NSView) {
        guard folderView.superview !== folderArea else { return }
        for subview in folderArea.subviews { subview.removeFromSuperview() }
        for subview in [folderView, message] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            folderArea.addSubview(subview)
        }
        let padding = Self.messagePadding
        NSLayoutConstraint.activate([
            folderView.leadingAnchor.constraint(equalTo: folderArea.leadingAnchor),
            folderView.trailingAnchor.constraint(equalTo: folderArea.trailingAnchor),
            folderView.topAnchor.constraint(equalTo: folderArea.topAnchor),
            folderView.bottomAnchor.constraint(equalTo: folderArea.bottomAnchor),
            message.centerXAnchor.constraint(equalTo: folderArea.centerXAnchor),
            message.centerYAnchor.constraint(equalTo: folderArea.centerYAnchor),
            message.leadingAnchor.constraint(
                greaterThanOrEqualTo: folderArea.leadingAnchor, constant: padding),
            message.trailingAnchor.constraint(
                lessThanOrEqualTo: folderArea.trailingAnchor, constant: -padding),
        ])
    }

    /// Says why the folder shows nothing: it cannot be read, or nothing in it
    /// is shown.
    private func showMessage(content: TreewiseUI.TabContent, isEmpty: Bool) {
        if let failure = content.failure {
            message.stringValue = FailureMessage.text(for: failure, locale: .autoupdatingCurrent)
            message.textColor = .labelColor
            message.isHidden = false
        } else if isEmpty && content.folder != nil {
            message.stringValue = ListPlaceholder.text(
                query: content.query, locale: .autoupdatingCurrent)
            message.textColor = .secondaryLabelColor
            message.isHidden = false
        } else {
            message.isHidden = true
        }
    }

    /// The items cut to the clipboard, which the folder dims.
    private var cutItems: Set<FileItem.ID> {
        guard let clipboard = browser.clipboard, clipboard.mode == .cut else { return [] }
        return Set(clipboard.items.map(\.id))
    }

    private func statusText(items: [FileItem], content: TreewiseUI.TabContent) -> String {
        let selected = items.filter { content.selection.contains($0.id) }
        return StatusLine.text(
            itemCount: items.count, selectedCount: content.selection.count,
            selectedSize: selected.compactMap(\.size).reduce(0, +),
            availableCapacity: content.availableCapacity, locale: .autoupdatingCurrent)
    }

    // MARK: - Downloads

    /// Follows the downloads of `files`, when they are others than those followed.
    /// A download that ends changes the file, so the folder is read again,
    /// which also ends this following for that file.
    private func followDownloads(of files: [FileItem.ID]) {
        guard files != followed else { return }
        followed = files
        following?.cancel()
        following = Task { [weak self] in
            for await report in DownloadMonitor().downloads(of: files) {
                guard let self else { return }
                let ended = report.count < downloads.count
                show(downloads: report)
                if ended { await browser.refresh(pane: paneIndex) }
            }
            self?.show(downloads: [:])
        }
    }

    private func show(downloads report: [FileItem.ID: Double]) {
        guard downloads != report else { return }
        downloads = report
        update()
    }

    private static func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
