import AppKit
import TreewiseCore
import TreewiseUI

/// The list of proposals under a name being renamed (ADR 0066). It is a window of its own
/// that never becomes key, so the name keeps the keyboard and the add-ons keep working
/// while it is open, which a menu would hold up: macOS runs no tasks while a menu tracks.
@MainActor
final class NameSuggestionPanel: NSObject {
    /// One line of the list.
    enum Row {
        /// A line that cannot be chosen, such as "Reading the file…".
        case note(String)
        /// A proposed name.
        case option(NameOption)
        case separator
        /// Suggest Names…, which opens the overview.
        case overview

        var canBeChosen: Bool {
            switch self {
            case .option, .overview: true
            case .note, .separator: false
            }
        }
    }

    /// The space between the field and the list below it.
    private static let gapBelowField: CGFloat = 2
    /// The space around the lines, as in a menu.
    private static let inset: CGFloat = 5
    private static let rowHeight: CGFloat = 22
    private static let cornerRadius: CGFloat = 6
    /// The narrowest the list gets, so a short name still has room for its options.
    private static let minimumWidth: CGFloat = 220

    /// Called with the index of the row the user clicked.
    var onChoose: ((Int) -> Void)?
    private(set) var rows: [Row] = []
    private(set) var highlighted: Int?

    private let window: FloatingList
    private let stack = NSStackView()
    private var buttons: [Int: SuggestionRowButton] = [:]

    override init() {
        window = FloatingList(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true)
        super.init()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = Self.cornerRadius
        background.layer?.masksToBounds = true
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(
            top: Self.inset, left: Self.inset, bottom: Self.inset, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        window.contentView = background
    }

    /// Shows these rows under the field, in its window.
    func show(_ rows: [Row], under field: NSTextField) {
        self.rows = rows
        highlighted = nil
        rebuild()
        place(under: field)
        if window.parent == nil { field.window?.addChildWindow(window, ordered: .above) }
    }

    /// Moves the highlight to the next row that can be chosen, or the previous one,
    /// going round at the ends.
    func moveHighlight(by step: Int) {
        let choosable = rows.indices.filter { rows[$0].canBeChosen }
        guard !choosable.isEmpty else { return }
        let next: Int
        if let current = highlighted, let position = choosable.firstIndex(of: current) {
            next = choosable[(position + step + choosable.count) % choosable.count]
        } else {
            next = step > 0 ? choosable[0] : choosable[choosable.count - 1]
        }
        highlight(next)
    }

    /// Highlights a row, or none.
    func highlight(_ index: Int?) {
        highlighted = index
        for (row, button) in buttons { button.isHighlightedRow = row == index }
    }

    func close() {
        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
    }

    private func rebuild() {
        for view in stack.arrangedSubviews { view.removeFromSuperview() }
        buttons = [:]
        for (index, row) in rows.enumerated() {
            let view = makeView(for: row, at: index)
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(
                equalTo: stack.widthAnchor, constant: -2 * Self.inset
            ).isActive = true
        }
    }

    private func makeView(for row: Row, at index: Int) -> NSView {
        switch row {
        case .note(let text):
            let label = NSTextField(labelWithString: text)
            label.textColor = .secondaryLabelColor
            label.heightAnchor.constraint(equalToConstant: Self.rowHeight).isActive = true
            return label
        case .separator:
            let line = NSBox()
            line.boxType = .separator
            return line
        case .option(let option):
            return button(title: title(of: option), warnings: warnings(of: option), at: index)
        case .overview:
            return button(
                title: NSAttributedString(string: String(localized: "Suggest Names…")),
                warnings: [], at: index)
        }
    }

    private func button(title: NSAttributedString, warnings: [String], at index: Int)
        -> SuggestionRowButton
    {
        let button = SuggestionRowButton(title: title)
        button.tag = index
        button.target = self
        button.action = #selector(clicked(_:))
        button.onHover = { [weak self] in self?.highlight(index) }
        button.heightAnchor.constraint(equalToConstant: Self.rowHeight).isActive = true
        if !warnings.isEmpty {
            button.image = NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: String(localized: "Warning"))
            button.imagePosition = .imageTrailing
            button.toolTip = warnings.joined(separator: "\n")
        }
        buttons[index] = button
        return button
    }

    /// The name, with its fields in their colours (ADR 0064).
    private func title(of option: NameOption) -> NSAttributedString {
        let title = NSMutableAttributedString(string: option.name)
        for mark in option.marks {
            title.addAttribute(
                .backgroundColor, value: FieldColors.color(mark.colorIndex),
                range: NSRange(mark.range, in: option.name))
        }
        return title
    }

    private func warnings(of option: NameOption) -> [String] {
        option.personalData.map(NameReviewText.text(for:))
            + (option.hasGap ? [String(localized: "Fill in the gap to approve")] : [])
    }

    private func place(under field: NSTextField) {
        guard let fieldWindow = field.window else { return }
        let frame = fieldWindow.convertToScreen(field.convert(field.bounds, to: nil))
        let size = stack.fittingSize
        let width = max(size.width, frame.width, Self.minimumWidth)
        window.setFrame(
            NSRect(
                x: frame.minX, y: frame.minY - Self.gapBelowField - size.height,
                width: width, height: size.height),
            display: true)
    }

    @objc private func clicked(_ sender: NSButton) {
        onChoose?(sender.tag)
    }
}

/// A window that never takes the keyboard from the name being renamed.
private final class FloatingList: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// One line of the list that can be chosen, highlighted as in a menu.
private final class SuggestionRowButton: NSButton {
    private static let cornerRadius: CGFloat = 4

    var onHover: (() -> Void)?
    var isHighlightedRow = false {
        didSet { showHighlight() }
    }
    private let plainTitle: NSAttributedString

    init(title: NSAttributedString) {
        let font = NSFont.menuFont(ofSize: 0)
        let plain = NSMutableAttributedString(attributedString: title)
        plain.addAttribute(.font, value: font, range: NSRange(location: 0, length: plain.length))
        plainTitle = plain
        super.init(frame: .zero)
        isBordered = false
        alignment = .left
        wantsLayer = true
        layer?.cornerRadius = Self.cornerRadius
        attributedTitle = plain
        setAccessibilityLabel(title.string)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    // The list never becomes key, so the first click has to count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?()
    }

    private func showHighlight() {
        layer?.backgroundColor =
            isHighlightedRow ? NSColor.selectedContentBackgroundColor.cgColor : nil
        guard isHighlightedRow else {
            attributedTitle = plainTitle
            return
        }
        let title = NSMutableAttributedString(attributedString: plainTitle)
        title.addAttribute(
            .foregroundColor, value: NSColor.alternateSelectedControlTextColor,
            range: NSRange(location: 0, length: title.length))
        attributedTitle = title
    }
}
