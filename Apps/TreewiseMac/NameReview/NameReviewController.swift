import AppKit
import TreewiseCore
import TreewiseUI

/// The overview of proposed names: the add-ons, the list and the panel beside it, and the
/// footer with the count and the buttons; once applied, what applying did.
@MainActor
final class NameReviewController: NSViewController {
    private static let panelWidth: CGFloat = 300
    /// The room around the footer's buttons, as around a window's content elsewhere.
    private static let footerPadding: CGFloat = 20
    /// Whether the panel beside the list shows, kept between reviews.
    private static let panelKey = "nameReviewShowsPanel"

    private let model: NameReviewModel
    private let browser: BrowserState
    private let fileUndo: UndoManager?
    private let close: () -> Void
    private lazy var addOns = NameReviewAddOnsView(model: model, licences: browser.licences)
    private lazy var list = NameReviewList(model: model)
    private lazy var panel = NameReviewPanel(model: model)
    private let summary = NSTextField(labelWithString: "")
    /// What add-ons see, at the foot (ADR 0057, ADR 0090).
    private let note = NSTextField(labelWithString: "")
    private lazy var panelView = panel.makeView(width: Self.panelWidth)
    private let panelLine = NSBox()
    private lazy var previewButton = ClosureButton(title: "") { [weak self] in
        self?.togglePanel()
    }
    private lazy var rename = ClosureButton(title: "") { [weak self] in self?.apply() }
    private var showsResult = false

    init(
        model: NameReviewModel, browser: BrowserState, undoManager fileUndo: UndoManager?,
        close: @escaping () -> Void
    ) {
        self.model = model
        self.browser = browser
        self.fileUndo = fileUndo
        self.close = close
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private var showsPanel: Bool {
        get { UserDefaults.standard.object(forKey: Self.panelKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.panelKey) }
    }

    override func loadView() {
        panelLine.boxType = .separator
        let middle = NSStackView(views: [list.makeView(), panelLine, panelView])
        middle.spacing = 0
        middle.alignment = .height
        // The add-ons at the top and the footer at the bottom, and the list between them
        // takes the height they leave.
        let parts = [addOns.makeView(), Self.line(), middle, Self.line(), footer()]
        let view = NSView()
        for part in parts {
            part.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(part)
            NSLayoutConstraint.activate([
                part.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                part.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
        }
        for (above, below) in zip(parts, parts.dropFirst()) {
            below.topAnchor.constraint(equalTo: above.bottomAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            parts[0].topAnchor.constraint(equalTo: view.topAnchor),
            parts[parts.count - 1].bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        // A stack view has no height of its own to hug, so the add-ons and the footer are
        // pulled to the least height their contents allow.
        for part in parts where part !== middle {
            let least = part.heightAnchor.constraint(equalToConstant: 0)
            least.priority = .defaultLow
            least.isActive = true
        }
        self.view = view
        Observing.follow(self) { $0.update() }
    }

    private func footer() -> NSView {
        summary.textColor = .secondaryLabelColor
        note.font = .preferredFont(forTextStyle: .caption1)
        note.textColor = .tertiaryLabelColor
        note.lineBreakMode = .byTruncatingTail
        note.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let model = model
        let approveAll = ClosureButton(title: String(localized: "Approve All")) {
            model.approveAll()
        }
        let cancel = ClosureButton(title: String(localized: "Cancel")) { [close] in close() }
        cancel.keyEquivalent = "\u{1b}"
        rename.keyEquivalent = "\r"
        rename.keyEquivalentModifierMask = .command
        rename.bezelColor = .controlAccentColor
        let row = NSStackView()
        row.setViews([summary, note], in: .leading)
        row.setViews([previewButton, approveAll, cancel, rename], in: .trailing)
        row.edgeInsets = NSEdgeInsets(
            top: Self.footerPadding, left: Self.footerPadding, bottom: Self.footerPadding,
            right: Self.footerPadding)
        // The footer is pulled to its least height, which its edge insets alone do not hold,
        // so it keeps the buttons and the room around them by a constraint of its own.
        row.heightAnchor.constraint(
            greaterThanOrEqualTo: rename.heightAnchor, constant: 2 * Self.footerPadding
        ).isActive = true
        return row
    }

    private func update() {
        if let outcome = model.outcome {
            showResult(outcome)
            return
        }
        let approved = model.session?.approvedRenames.count ?? 0
        summary.stringValue = String(localized: "\(approved) of \(model.rows.count) approved")
        note.stringValue =
            model.readsYearBefore
            ? String(
                localized:
                    "Add-ons see only the names of files they handle, here and in the same folder a year before, and cannot reach the internet."
            )
            : String(
                localized: "Add-ons see only files they handle, and cannot reach the internet.")
        note.toolTip = note.stringValue
        rename.title =
            approved == 0
            ? String(localized: "Rename") : String(localized: "Rename \(approved) Items")
        rename.isEnabled = model.canApply
        showPanel()
    }

    private func showPanel() {
        let shows = showsPanel
        panelView.isHidden = !shows
        panelLine.isHidden = !shows
        previewButton.title =
            shows ? String(localized: "Hide Preview") : String(localized: "Show Preview")
    }

    private func togglePanel() {
        showsPanel.toggle()
        showPanel()
    }

    private func apply() {
        let model = model
        let browser = browser
        let fileUndo = fileUndo
        Task {
            await model.apply()
            if let outcome = model.outcome {
                await browser.finishNameReview(outcome, undoManager: fileUndo)
            }
        }
    }

    private func showResult(_ outcome: BatchRenameOutcome) {
        guard !showsResult else { return }
        showsResult = true
        let fileUndo = fileUndo
        let close = close
        let result = NameReviewResultView(outcome: outcome) {
            fileUndo?.undo()
            close()
        } done: {
            close()
        }
        view.window?.contentView = result
    }

    private static func line() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
