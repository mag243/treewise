import AppKit
import SwiftUI
import TreewiseCore
import TreewiseUI

/// The menu of saved patterns beside an add-on's pattern (ADR 0068): each by its name,
/// with its text in the colours of its fields and the current one checked; one the add-on
/// cannot use is dimmed, with the reason as its tooltip. Then Save Pattern… and Edit Saved
/// Patterns…. A menu of our own, as SwiftUI's shows no colours in its items.
struct SavedPatternsMenu: NSViewRepresentable {
    /// The button's text, or nil for an icon.
    let title: String?
    let choices: () -> [SavedPatternChoice]
    let use: (SavedPattern.ID) -> Void
    let save: () -> Void
    let edit: () -> Void

    func makeNSView(context: Context) -> MenuButton {
        MenuButton()
    }

    func updateNSView(_ button: MenuButton, context: Context) {
        button.show(title: title)
        button.choices = choices
        button.use = use
        button.save = save
        button.edit = edit
    }

    @MainActor
    final class MenuButton: NSButton {
        /// The space between the button and the menu below it.
        private static let menuGap: CGFloat = 4
        /// The space between a pattern's name and its text.
        private static let separator = "   "

        var choices: () -> [SavedPatternChoice] = { [] }
        var use: (SavedPattern.ID) -> Void = { _ in }
        var save: () -> Void = {}
        var edit: () -> Void = {}

        init() {
            super.init(frame: .zero)
            isBordered = false
            target = self
            action = #selector(showMenu)
            setContentHuggingPriority(.required, for: .horizontal)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        func show(title: String?) {
            let label = String(localized: "Saved Patterns")
            setAccessibilityLabel(title ?? label)
            toolTip = title == nil ? label : nil
            guard let title else {
                self.title = ""
                image = NSImage(systemSymbolName: "bookmark", accessibilityDescription: label)
                imagePosition = .imageOnly
                contentTintColor = .secondaryLabelColor
                return
            }
            image = nil
            attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .foregroundColor: NSColor.linkColor,
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                ])
        }

        @objc private func showMenu() {
            let menu = NSMenu()
            menu.autoenablesItems = false
            for choice in choices() { menu.addItem(item(for: choice)) }
            menu.addItem(.separator())
            menu.addItem(action("Save Pattern…", #selector(saveChosen)))
            menu.addItem(action("Edit Saved Patterns…", #selector(editChosen)))
            let below = isFlipped ? bounds.maxY + Self.menuGap : bounds.minY - Self.menuGap
            menu.popUp(positioning: nil, at: CGPoint(x: bounds.minX, y: below), in: self)
        }

        private func item(for choice: SavedPatternChoice) -> NSMenuItem {
            let item = NSMenuItem(
                title: choice.pattern.name, action: #selector(useChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.pattern.id
            item.state = choice.isCurrent ? .on : .off
            item.isEnabled = choice.problem == nil
            let title = NSMutableAttributedString(
                string: choice.pattern.name + Self.separator,
                attributes: [.font: NSFont.menuFont(ofSize: 0)])
            let text = NSMutableAttributedString(
                string: choice.pattern.text,
                attributes: [
                    .font: NSFont.monospacedSystemFont(
                        ofSize: NSFont.smallSystemFontSize, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ])
            for mark in FieldColors.marks(inPattern: choice.pattern.text) {
                text.addAttribute(
                    .backgroundColor, value: FieldColors.color(mark.colorIndex), range: mark.range)
            }
            title.append(text)
            item.attributedTitle = title
            if let problem = choice.problem { item.toolTip = NameReviewText.text(for: problem) }
            return item
        }

        private func action(_ title: String.LocalizationValue, _ selector: Selector) -> NSMenuItem {
            let item = NSMenuItem(
                title: String(localized: title), action: selector, keyEquivalent: "")
            item.target = self
            return item
        }

        @objc private func useChosen(_ item: NSMenuItem) {
            if let id = item.representedObject as? String { use(id) }
        }

        @objc private func saveChosen() { save() }

        @objc private func editChosen() { edit() }
    }
}
