import AppKit
import TreewiseCore
import TreewiseUI

/// The side of a row in the overview: the other options, the position among them, a
/// warning and, for the selected row, Skip.
extension NameReviewRowView {
    func sideViews(_ entry: NameProposalSession.Entry, _ isSelected: Bool) -> [NSView] {
        let model = model
        let id = id
        let steps = isSelected && entry.proposals.count + (entry.edit == nil ? 0 : 1) > 1
        var views: [NSView] = []
        if steps {
            views.append(Self.arrow("chevron.left") { model.step(id, by: .previous) })
        }
        let position = NSTextField(
            labelWithString: entry.position.map { "\($0.index + 1)/\($0.count)" } ?? "")
        position.font = .monospacedDigitSystemFont(
            ofSize: NSFont.smallSystemFontSize, weight: .regular)
        position.textColor = .secondaryLabelColor
        views.append(position)
        if steps { views.append(Self.arrow("chevron.right") { model.step(id, by: .next) }) }
        let warning = NSImageView(
            image: NSImage(
                systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
                ?? NSImage())
        warning.contentTintColor = .systemOrange
        warning.alphaValue = hasProblem(entry) ? 1 : 0
        views.append(warning)
        if isSelected, let skip = skipControl(entry) { views.append(skip) }
        return views
    }

    private func hasProblem(_ entry: NameProposalSession.Entry) -> Bool {
        model.conflicts[entry.id] != nil || !entry.personalData.isEmpty
            || (entry.currentName != nil && entry.problem != nil && entry.problem != .unchanged)
    }

    private static func arrow(_ symbol: String, run: @escaping @MainActor () -> Void)
        -> NSButton
    {
        let button = ActionButton(title: "", symbol: symbol, run: run)
        button.setAccessibilityLabel(
            symbol == "chevron.left" ? String(localized: "Previous") : String(localized: "Next"))
        return button
    }

    private func skipControl(_ entry: NameProposalSession.Entry) -> NSView? {
        let model = model
        let id = id
        if model.isAlwaysSkipped(id) {
            return LinkButton(String(localized: "Back in List")) {
                Task { await model.stopAlwaysSkipping(id) }
            }
        }
        if entry.state == .skipped {
            return LinkButton(String(localized: "Undo Skip")) { model.undecide(id) }
        }
        guard !entry.restsFitting, !entry.isOutOfScope else { return nil }
        let skip = NSPopUpButton(frame: .zero, pullsDown: true)
        skip.isBordered = false
        skip.controlSize = .small
        skip.font = .preferredFont(forTextStyle: .caption1)
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Skip"), action: nil, keyEquivalent: "")
        menu.addItem(ActionMenuItem(title: String(localized: "Skip")) { model.skip(id) })
        menu.addItem(
            ActionMenuItem(title: String(localized: "Always Skip")) {
                Task { await model.alwaysSkip(id) }
            })
        skip.menu = menu
        skip.setAccessibilityLabel(String(localized: "Skip"))
        return skip
    }
}
