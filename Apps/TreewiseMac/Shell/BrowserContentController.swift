import AppKit
import TreewiseUI

/// The folder side of a browser window: the address row, the command bar, the
/// folder and the details pane, one under the other in a stack view, with the
/// progress of a transfer over them.
@MainActor
final class BrowserContentController: NSViewController {
    /// The space between the progress panel and the bottom of the window.
    private static let progressMargin: CGFloat = 12

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
        let progress = OperationProgressView(browser: browser)
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
            progress.bottomAnchor.constraint(
                equalTo: view.bottomAnchor, constant: -Self.progressMargin),
        ])
        self.view = view
        Observing.follow(self) { $0.update() }
    }

    private func update() {
        details.isHidden = !browser.settings.showsDetails
    }

    private func addressRow() -> NSView {
        AddressBar(browser: browser, model: model)
    }

    private func commandBar() -> NSView {
        CommandBar(browser: browser, windowBeside: windowBeside)
    }

    /// The folder, and the details pane at its right when shown.
    private func folderRow() -> NSView {
        let paneController = PaneController(browser: browser)
        addChild(paneController)
        let pane = paneController.view
        pane.setContentHuggingPriority(.defaultLow, for: .horizontal)
        pane.setContentHuggingPriority(.defaultLow, for: .vertical)
        let detailsPane = DetailsPane(browser: browser)
        let line = Self.separator()
        line.widthAnchor.constraint(equalToConstant: 1).isActive = true
        details.setViews([line, detailsPane], in: .leading)
        details.spacing = 0
        details.distribution = .fill
        details.alignment = .height
        // The pane and its line run from the top of the folder down: a stack view's
        // alignment does not stretch a view whose content gives it a height of its own.
        for view in [line, detailsPane] {
            view.heightAnchor.constraint(equalTo: details.heightAnchor).isActive = true
        }
        // The details are as wide as the pane, and the folder takes the rest.
        details.setHuggingPriority(.defaultHigh, for: .horizontal)
        let row = NSStackView(views: [pane, details])
        row.spacing = 0
        // The width the details leave goes to the folder, not between them.
        row.distribution = .fill
        row.alignment = .height
        row.setContentHuggingPriority(.defaultLow, for: .vertical)
        return row
    }

    private static func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
