import AppKit
import TreewiseCore
import TreewiseUI

/// The menu of patterns beside an add-on's pattern: first the patterns the add-on found in
/// this folder, each with how many names fit it (ADR 0067), then the saved patterns by name
/// (ADR 0068), each with its text in the colours of its fields and the current one checked;
/// a saved one the add-on cannot use is dimmed, with the reason as its tooltip. Then Save
/// Pattern… and Edit Saved Patterns…; when the folder changed a pattern picked from a saved
/// one, Update "name" and Save as New Pattern… in place of Save Pattern…. The menu is built
/// each time it opens, so it shows the add-on as it is then.
@MainActor
final class SavedPatternsMenu: NSButton {
    /// The space between the button and the menu below it.
    private static let menuGap: CGFloat = 4
    /// The space between a pattern's name and its text.
    private static let separator = "   "

    var choices: () -> [SavedPatternChoice] = { [] }
    var found: () -> (candidates: [PatternCandidate], current: String) = { ([], "") }
    var use: (SavedPattern.ID) -> Void = { _ in }
    var useFound: (String) -> Void = { _ in }
    var toUpdate: () -> String? = { nil }
    var update: () -> Void = {}
    var save: () -> Void = {}
    var edit: () -> Void = {}

    /// A button with `title`, or an icon when nil.
    init(title: String?) {
        super.init(frame: .zero)
        isBordered = false
        target = self
        action = #selector(showMenu)
        setContentHuggingPriority(.required, for: .horizontal)
        show(title: title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func show(title: String?) {
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
        let (candidates, current) = found()
        if !candidates.isEmpty {
            menu.addItem(.sectionHeader(title: String(localized: "Found in This Folder")))
            for candidate in candidates {
                menu.addItem(item(for: candidate, isCurrent: candidate.text == current))
            }
            menu.addItem(.sectionHeader(title: String(localized: "Saved")))
        }
        for choice in choices() { menu.addItem(item(for: choice)) }
        menu.addItem(.separator())
        if let name = toUpdate() {
            menu.addItem(action("Update “\(name)”", #selector(updateChosen)))
            menu.addItem(action("Save as New Pattern…", #selector(saveChosen)))
        } else {
            menu.addItem(action("Save Pattern…", #selector(saveChosen)))
        }
        menu.addItem(action("Edit Saved Patterns…", #selector(editChosen)))
        let below = isFlipped ? bounds.maxY + Self.menuGap : bounds.minY - Self.menuGap
        menu.popUp(positioning: nil, at: CGPoint(x: bounds.minX, y: below), in: self)
    }

    /// A pattern found in the folder, in the colours of its fields, with how many of the
    /// folder's names fit it.
    private func item(for candidate: PatternCandidate, isCurrent: Bool) -> NSMenuItem {
        let item = NSMenuItem(
            title: candidate.text, action: #selector(useFoundChosen(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = candidate.text
        item.state = isCurrent ? .on : .off
        let title = NSMutableAttributedString(attributedString: Self.coloured(candidate.text))
        title.append(
            NSAttributedString(
                string: Self.separator
                    + String(localized: "\(candidate.fits) of \(candidate.of) names"),
                attributes: [
                    .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        item.attributedTitle = title
        return item
    }

    /// A pattern's text, with each field in its colour.
    private static func coloured(_ pattern: String) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: pattern,
            attributes: [
                .font: NSFont.monospacedSystemFont(
                    ofSize: NSFont.smallSystemFontSize, weight: .regular)
            ])
        for mark in FieldColors.marks(inPattern: pattern) {
            text.addAttribute(.backgroundColor, value: mark.color, range: mark.range)
        }
        return text
    }

    @objc private func useFoundChosen(_ item: NSMenuItem) {
        if let text = item.representedObject as? String { useFound(text) }
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
                .backgroundColor, value: mark.color, range: mark.range)
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

    @objc private func updateChosen() { update() }

    @objc private func editChosen() { edit() }
}
