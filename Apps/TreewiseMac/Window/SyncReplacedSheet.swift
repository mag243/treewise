import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// The safety net of syncing (ADR 0144): each change of this Mac's that another device's
/// replaced without seeing it, with what this Mac had and what holds now, and Restore.
@MainActor
final class SyncReplacedSheet: NSViewController {
    private static let size = CGSize(width: 560, height: 360)
    private static let spacing: CGFloat = 12

    private let sync: SyncController
    private let settings: BrowserSettings
    private let rows = NSStackView()

    init(sync: SyncController, settings: BrowserSettings) {
        self.sync = sync
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let title = NSTextField(
            labelWithString: String(localized: "Changes Replaced by Another Device"))
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = Self.spacing
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        rows.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(rows)
        scroll.documentView = document
        NSLayoutConstraint.activate([
            rows.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            rows.topAnchor.constraint(equalTo: document.topAnchor),
            rows.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])
        let kept = NSTextField(labelWithString: String(localized: "Kept for 30 days on this Mac."))
        kept.textColor = .secondaryLabelColor
        let clear = NSButton(
            title: String(localized: "Clear"), target: self, action: #selector(clear))
        let done = NSButton(title: String(localized: "Done"), target: self, action: #selector(done))
        done.keyEquivalent = "\r"
        let bottom = NSStackView(views: [kept, NSView(), clear, done])
        let stack = NSStackView(views: [title, scroll, bottom])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        for view in [scroll, bottom] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        }
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        stack.setFrameSize(Self.size)
        view = stack
        Observing.follow(self) { $0.update() }
    }

    private func update() {
        for row in rows.arrangedSubviews { row.removeFromSuperview() }
        let templates = FolderTemplatesService.templates.templates
        for entry in sync.replaced {
            let text = SyncConflictText(entry) { element in
                switch element {
                case .pattern(let id):
                    self.settings.savedPatterns.patterns.first { $0.id == id }?.name
                case .template(let id): templates.first { $0.id == id }?.name
                default: nil
                }
            }
            rows.addArrangedSubview(row(for: entry, text: text))
        }
    }

    private func row(for entry: SyncConflictStore.Entry, text: SyncConflictText) -> NSView {
        let heading = NSTextField(labelWithString: "\(text.title) · \(text.part)")
        heading.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        let when = entry.conflict.winner.changedAt.formatted(date: .abbreviated, time: .shortened)
        let source = NSTextField(
            labelWithString: [entry.byDevice, when].compactMap { $0 }.joined(separator: " · "))
        source.textColor = .secondaryLabelColor
        let values = NSTextField(
            wrappingLabelWithString: String(localized: "Yours: \(text.yours)   Now: \(text.now)"))
        let restore = NSButton(
            title: String(localized: "Restore"), target: self, action: #selector(restore(_:)))
        restore.identifier = NSUserInterfaceItemIdentifier(entry.id)
        let top = NSStackView(views: [heading, NSView(), source])
        let bottom = NSStackView(views: [values, NSView(), restore])
        let row = NSStackView(views: [top, bottom])
        row.orientation = .vertical
        row.alignment = .leading
        for line in [top, bottom] {
            line.widthAnchor.constraint(equalTo: row.widthAnchor).isActive = true
        }
        return row
    }

    @objc private func restore(_ button: NSButton) {
        guard let entry = sync.replaced.first(where: { $0.id == button.identifier?.rawValue })
        else { return }
        Task { await sync.restore(entry) }
    }

    @objc private func clear() {
        Task { await sync.clearReplaced() }
        dismiss(nil)
    }

    @objc private func done() {
        dismiss(nil)
    }
}
