import AppKit
import TreewiseCore
import TreewiseUI

/// What applying the overview did, and the way back.
@MainActor
final class NameReviewResultView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private static let padding: CGFloat = 20
    private static let spacing: CGFloat = 10

    private let names: [String]

    /// The view for `outcome`; `undo` takes the renaming back, `done` closes.
    init(
        outcome: BatchRenameOutcome, undo: @escaping @MainActor () -> Void,
        done: @escaping @MainActor () -> Void
    ) {
        names = outcome.renamed.map(\.item.name)
        super.init(frame: .zero)
        let title = NSTextField(
            labelWithString: String(localized: "\(outcome.renamed.count) items renamed"))
        title.font = .preferredFont(forTextStyle: .headline)
        var views: [NSView] = [title]
        if let failure = outcome.failure { views.append(Self.warning(failure)) }
        views.append(list())
        let undoButton = ClosureButton(title: String(localized: "Undo Rename"), run: undo)
        let doneButton = ClosureButton(title: String(localized: "Done"), run: done)
        doneButton.keyEquivalent = "\r"
        let buttons = NSStackView()
        buttons.setViews([undoButton, doneButton], in: .trailing)
        views.append(buttons)
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        for view in views {
            view.widthAnchor.constraint(
                equalTo: stack.widthAnchor, constant: -Self.padding * 2
            ).isActive = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func list() -> NSView {
        let table = NSTableView()
        table.addTableColumn(NSTableColumn(identifier: .init("name")))
        table.headerView = nil
        table.style = .inset
        table.dataSource = self
        table.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        return scroll
    }

    private static func warning(_ failure: BatchRenameOutcome.Failure) -> NSView {
        let text: String
        if let temporary = failure.leftUnderTemporaryName {
            text = String(
                localized:
                    "Stopped: a name could not be given. A file is left as \(temporary); Undo Rename puts it back."
            )
        } else {
            text = String(
                localized: "Stopped: a name could not be given, and the rest stayed as it was.")
        }
        let icon = NSImageView(
            image: NSImage(
                systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
                ?? NSImage())
        icon.contentTintColor = .systemOrange
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .systemOrange
        return NSStackView(views: [icon, label])
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        names.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
        -> NSView?
    {
        let name = NSTextField(labelWithString: names[row])
        name.isSelectable = true
        return name
    }
}
