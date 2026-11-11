import AppKit
import TreewiseModuleInterface
import TreewiseUI

/// Enter Licence Key…, as Settings and the review's add-ons header offer it (ADR 0071): a
/// sheet with room for the whole key, Paste, and why a key unlocks nothing, shown in the
/// sheet so the user can try again. The closed modules judge the key; the app keeps it
/// only when one takes it, and then says what it unlocked in an alert.
@MainActor
enum LicenceKeyEntry {
    /// Shows the sheet on `window`; `onUnlocked` is called once a key unlocked an add-on.
    static func present(
        on window: NSWindow, keeper: LicenceKeeper?, host: any NameModuleHosting,
        onUnlocked: @escaping () -> Void = {}
    ) {
        let sheet = LicenceKeySheet(keeper: keeper, host: host)
        let sheetWindow = NSWindow(contentViewController: sheet)
        sheet.finish = { [weak window, weak sheetWindow] message in
            guard let window, let sheetWindow else { return }
            window.endSheet(sheetWindow)
            guard let message else { return }
            onUnlocked()
            let alert = NSAlert()
            alert.messageText = message
            alert.beginSheetModal(for: window)
        }
        window.beginSheet(sheetWindow)
    }
}

/// The sheet in which a key is pasted.
@MainActor
private final class LicenceKeySheet: NSViewController, NSTextViewDelegate {
    private static let width: CGFloat = 520
    private static let fieldHeight: CGFloat = 110
    private static let padding: CGFloat = 20
    private static let spacing: CGFloat = 12

    private let keeper: LicenceKeeper?
    private let host: any NameModuleHosting
    /// Called with what a key unlocked, or `nil` on Cancel.
    var finish: (String?) -> Void = { _ in }
    private let key = NSTextView()
    private let problem = NSTextField(labelWithString: "")
    private let problemIcon = NSImageView(
        image: NSImage(
            systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
            ?? NSImage())
    private lazy var add = ClosureButton(title: String(localized: "Add")) { [weak self] in
        self?.enter()
    }
    private var isChecking = false {
        didSet { updateAdd() }
    }

    init(keeper: LicenceKeeper?, host: any NameModuleHosting) {
        self.keeper = keeper
        self.host = host
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let title = NSTextField(labelWithString: String(localized: "Enter Licence Key"))
        title.font = .preferredFont(forTextStyle: .headline)
        let explanation = NSTextField(
            labelWithString: String(
                localized: "Paste the licence key from the e-mail you received."))
        explanation.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [title, explanation, keyField(), buttons()])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        view = stack
        updateAdd()
    }

    private func keyField() -> NSView {
        key.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        key.isRichText = false
        key.delegate = self
        key.setAccessibilityLabel(String(localized: "Licence key"))
        key.autoresizingMask = [.width]
        let scroll = NSScrollView()
        scroll.documentView = key
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(equalToConstant: Self.fieldHeight),
            scroll.widthAnchor.constraint(equalToConstant: Self.width - Self.padding * 2),
        ])
        return scroll
    }

    private func buttons() -> NSView {
        let paste = ClosureButton(title: String(localized: "Paste")) { [weak self] in
            if let text = NSPasteboard.general.string(forType: .string) {
                self?.key.string = text
                self?.keyChanged()
            }
        }
        problem.font = .preferredFont(forTextStyle: .caption1)
        problem.textColor = .systemOrange
        problemIcon.contentTintColor = .systemOrange
        show(problem: nil)
        let cancel = ClosureButton(title: String(localized: "Cancel")) { [weak self] in
            self?.finish(nil)
        }
        cancel.keyEquivalent = "\u{1b}"
        add.keyEquivalent = "\r"
        let row = NSStackView()
        row.setViews([paste, problemIcon, problem], in: .leading)
        row.setViews([cancel, add], in: .trailing)
        row.widthAnchor.constraint(equalToConstant: Self.width - Self.padding * 2).isActive = true
        return row
    }

    func textDidChange(_ notification: Notification) {
        keyChanged()
    }

    private func keyChanged() {
        show(problem: nil)
        updateAdd()
    }

    private func updateAdd() {
        add.isEnabled =
            !isChecking && !key.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func show(problem text: String?) {
        problem.stringValue = text ?? ""
        problem.isHidden = text == nil
        problemIcon.isHidden = text == nil
    }

    private func enter() {
        guard let keeper else { return }
        isChecking = true
        let text = key.string
        let host = host
        Task {
            let result = await keeper.enter(key: text, host: host)
            isChecking = false
            switch result {
            case .notAKey:
                show(problem: String(localized: "This is not a Treewise licence key."))
            case .unlocksNothing:
                show(
                    problem: String(
                        localized:
                            "This key unlocks none of your add-ons. It may be for another add-on, or withdrawn."
                    ))
            case .unlocked(let modules, let licensee):
                let names = modules.map { NameReviewText.name(ofModule: $0) }
                    .joined(separator: ", ")
                finish(String(localized: "Unlocked \(names) for \(licensee)."))
            }
        }
    }
}
