import AppKit
import TreewiseCore
import TreewiseUI

/// Explorer's command bar as a row of the window, under the address bar (ADR
/// 0037): New, the actions (ADR 0036), Sort and View as menus with a label,
/// and Window Beside and the details pane at the end. In a narrow window the
/// menus and buttons drop their titles and keep their icons, so nothing is
/// cut off.
@MainActor
final class CommandBar: NSView {
    private static let height: CGFloat = 34
    private static let padding: CGFloat = 8
    private static let dividerHeight: CGFloat = 18

    private let browser: BrowserState
    private let menus: CommandBarMenus
    private let actions: CommandBarActions
    private let row = NSStackView()
    private let windowBeside: () -> Void
    private lazy var newButton = pullDown(menus.new, "New", "plus.circle")
    private lazy var sortButton = pullDown(menus.sort, "Sort", "arrow.up.arrow.down")
    private lazy var viewButton = pullDown(menus.view, "View", "eye")
    private lazy var besideButton = button(
        "Window Beside", "rectangle.split.2x1", #selector(openBeside))
    private lazy var detailsButton = button("Details", "sidebar.right", #selector(toggleDetails))
    /// The titles of the buttons that drop them in a narrow window.
    private var titled: [(button: NSButton, title: String)] = []
    private var showsTitles = true
    /// The width the row needs with its titles.
    private var titledWidth: CGFloat = 0

    init(browser: BrowserState, windowBeside: @escaping () -> Void) {
        self.browser = browser
        self.windowBeside = windowBeside
        menus = CommandBarMenus(browser: browser)
        actions = CommandBarActions(browser: browser)
        super.init(frame: .zero)
        besideButton.toolTip = String(localized: "Open a window beside this one")
        detailsButton.setButtonType(.pushOnPushOff)
        detailsButton.toolTip = String(localized: "Show or hide the details pane")
        newButton.toolTip = String(localized: "Make something new in this folder")
        row.setViews(
            [newButton, Self.divider(), actions, Self.divider(), sortButton, viewButton],
            in: .leading)
        row.setViews([besideButton, detailsButton], in: .trailing)
        row.spacing = Self.padding
        row.edgeInsets = NSEdgeInsets(top: 0, left: Self.padding, bottom: 0, right: Self.padding)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: Self.height),
        ])
        for view in row.arrangedSubviews {
            view.setContentCompressionResistancePriority(
                CrumbButton.yieldsToWindow, for: .horizontal)
        }
        Observing.follow(self) { $0.update() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func update() {
        detailsButton.state = browser.settings.showsDetails ? .on : .off
        if actions.update() { remeasure() }
    }

    // MARK: - Titles in a narrow window

    override func layout() {
        super.layout()
        if showsTitles {
            titledWidth = row.fittingSize.width
            if titledWidth > bounds.width { show(titles: false) }
        } else if titledWidth <= bounds.width {
            show(titles: true)
        }
    }

    /// Measures the row with its titles again, as its buttons changed.
    private func remeasure() {
        if !showsTitles { show(titles: true) }
        needsLayout = true
    }

    private func show(titles: Bool) {
        showsTitles = titles
        for (button, title) in titled {
            if let pullDown = button as? NSPopUpButton {
                pullDown.menu?.items.first?.title = titles ? title : ""
                pullDown.synchronizeTitleAndSelectedItem()
            } else {
                button.imagePosition = titles ? .imageLeading : .imageOnly
            }
        }
        needsLayout = true
    }

    // MARK: - Buttons

    @objc private func openBeside() {
        windowBeside()
    }

    @objc private func toggleDetails() {
        browser.settings.showsDetails = detailsButton.state == .on
    }

    private func pullDown(_ menu: NSMenu, _ title: String.LocalizationValue, _ symbol: String)
        -> NSPopUpButton
    {
        let text = String(localized: title)
        let titleItem = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        titleItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        menus.setTitle(titleItem, of: menu)
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.menu = menu
        button.isBordered = false
        button.setAccessibilityLabel(text)
        titled.append((button, text))
        return button
    }

    private func button(_ title: String.LocalizationValue, _ symbol: String, _ action: Selector)
        -> NSButton
    {
        let text = String(localized: title)
        let button = NSButton(
            title: text,
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
                ?? NSImage(), target: self, action: action)
        button.isBordered = false
        button.imagePosition = .imageLeading
        titled.append((button, text))
        return button
    }

    private static func divider() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: dividerHeight),
            box.widthAnchor.constraint(equalToConstant: 1),
        ])
        return box
    }
}
