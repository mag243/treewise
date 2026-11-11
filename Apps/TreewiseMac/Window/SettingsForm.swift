import AppKit

/// The layout of a Settings pane as Mac apps have it: a grid with the labels
/// at the right of their column and the controls beside them, groups of rows
/// apart, and notes in small grey text under the controls they explain.
@MainActor
final class SettingsForm {
    /// The space around the grid in its pane.
    static let margin: CGFloat = 20
    private static let groupSpacing: CGFloat = 16
    private static let rowSpacing: CGFloat = 8
    private static let columnSpacing: CGFloat = 8

    let grid = NSGridView()
    private var startsGroup = false

    init() {
        grid.rowSpacing = Self.rowSpacing
        grid.columnSpacing = Self.columnSpacing
        grid.translatesAutoresizingMaskIntoConstraints = false
    }

    /// Adds a row of `label` and `control`, or of `control` alone under the
    /// controls when there is no label.
    func row(_ label: String.LocalizationValue?, _ control: NSView) {
        let title = label.map { NSTextField(labelWithString: String(localized: $0)) }
        let row = grid.addRow(with: [title ?? NSGridCell.emptyContentView, control])
        if startsGroup {
            row.topPadding = Self.groupSpacing
            startsGroup = false
        }
        row.rowAlignment = .firstBaseline
    }

    /// Adds a note under the controls.
    func note(_ text: String.LocalizationValue, width: CGFloat) {
        let note = NSTextField(wrappingLabelWithString: String(localized: text))
        note.font = .preferredFont(forTextStyle: .footnote)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = width
        grid.addRow(with: [NSGridCell.emptyContentView, note])
    }

    /// Puts the next row a group apart.
    func group() {
        startsGroup = grid.numberOfRows > 0
    }

    /// The grid in a view of `size`, at the top, in the middle.
    func pane(size: CGSize) -> NSView {
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        view.addSubview(grid)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size.width),
            view.heightAnchor.constraint(equalToConstant: size.height),
            grid.topAnchor.constraint(equalTo: view.topAnchor, constant: Self.margin),
            grid.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grid.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor, constant: Self.margin),
        ])
        return view
    }

    // MARK: - Controls

    /// A checkbox that calls `change` with its new state.
    static func checkbox(
        _ title: String.LocalizationValue, change: @escaping @MainActor (Bool) -> Void
    ) -> NSButton {
        let box = ClosureCheckbox(title: String(localized: title), change: change)
        return box
    }

    /// A pop-up of `titles` that calls `choose` with the index chosen.
    static func popUp(
        _ titles: [String], accessibilityLabel: String.LocalizationValue,
        choose: @escaping @MainActor (Int) -> Void
    ) -> NSPopUpButton {
        let popUp = ClosurePopUp(choose: choose)
        popUp.addItems(withTitles: titles)
        popUp.setAccessibilityLabel(String(localized: accessibilityLabel))
        return popUp
    }

    /// A push button that runs `run`.
    static func button(_ title: String.LocalizationValue, run: @escaping @MainActor () -> Void)
        -> NSButton
    {
        ClosureButton(title: String(localized: title), run: run)
    }
}

/// A checkbox that reports its state to a closure.
@MainActor
final class ClosureCheckbox: NSButton {
    private let change: @MainActor (Bool) -> Void

    init(title: String, change: @escaping @MainActor (Bool) -> Void) {
        self.change = change
        super.init(frame: .zero)
        setButtonType(.switch)
        self.title = title
        target = self
        action = #selector(changed)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func changed() {
        change(state == .on)
    }
}

/// A pop-up button that reports the index chosen to a closure.
@MainActor
final class ClosurePopUp: NSPopUpButton {
    private let choose: @MainActor (Int) -> Void

    init(choose: @escaping @MainActor (Int) -> Void) {
        self.choose = choose
        super.init(frame: .zero, pullsDown: false)
        target = self
        action = #selector(chose)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func chose() {
        choose(indexOfSelectedItem)
    }
}

/// A push button that runs a closure, named for VoiceOver by its title.
@MainActor
final class ClosureButton: NSButton {
    private let run: @MainActor () -> Void

    override var title: String {
        didSet { setAccessibilityLabel(title) }
    }

    init(title: String, run: @escaping @MainActor () -> Void) {
        self.run = run
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .push
        target = self
        action = #selector(clicked)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func clicked() {
        run()
    }
}
