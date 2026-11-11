import AppKit
import SwiftUI
import TreewiseUI

/// The folder side of a browser window: the address row, the command bar, the
/// folder and the details pane, one under the other in a stack view, with the
/// progress of a transfer over them.
@MainActor
final class BrowserContentController: NSViewController {
    private let browser: BrowserState
    private let model: WindowModel
    private let windowBeside: () -> Void
    private let details = NSStackView()

    init(browser: BrowserState, model: WindowModel, windowBeside: @escaping () -> Void) {
        self.browser = browser
        self.model = model
        self.windowBeside = windowBeside
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let rows = NSStackView(views: [
            addressRow(), Self.separator(), commandBar(), Self.separator(), folderRow(),
        ])
        rows.orientation = .vertical
        rows.spacing = 0
        rows.alignment = .leading
        for row in rows.arrangedSubviews {
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        let progress = Self.hosting(OperationProgressView(browser: browser))
        let view = NSView()
        view.addSubview(rows)
        view.addSubview(progress)
        rows.translatesAutoresizingMaskIntoConstraints = false
        progress.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rows.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rows.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            progress.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progress.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.view = view
        Observing.follow(self) { $0.update() }
    }

    private func update() {
        details.isHidden = !browser.settings.showsDetails
    }

    private func addressRow() -> NSView {
        let model = model
        let isEditing = Binding(
            get: { model.isEditingAddress }, set: { model.isEditingAddress = $0 })
        let row = Self.hosting(AddressRow(browser: browser, isEditing: isEditing))
        row.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return row
    }

    private func commandBar() -> NSView {
        let bar = Self.hosting(
            CommandBar(
                browser: browser, undoManager: SharedUndo.manager, windowBeside: windowBeside))
        bar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return bar
    }

    /// The folder, and the details pane at its right when shown.
    private func folderRow() -> NSView {
        let pane = Self.hosting(
            PaneView(browser: browser, paneIndex: browser.layout.focusedPaneIndex))
        pane.sizingOptions = [.minSize]
        pane.setContentHuggingPriority(.defaultLow, for: .horizontal)
        pane.setContentHuggingPriority(.defaultLow, for: .vertical)
        let detailsPane = Self.hosting(DetailsPane(browser: browser))
        detailsPane.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        detailsPane.setContentHuggingPriority(.defaultLow, for: .vertical)
        details.setViews([Self.separator(), detailsPane], in: .leading)
        details.spacing = 0
        details.alignment = .height
        let row = NSStackView(views: [pane, details])
        row.spacing = 0
        row.alignment = .height
        row.setContentHuggingPriority(.defaultLow, for: .vertical)
        return row
    }

    private static func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private static func hosting(_ view: some View) -> NSHostingView<some View> {
        NSHostingView(rootView: view.environment(\.fileUndoManager, SharedUndo.manager))
    }
}
