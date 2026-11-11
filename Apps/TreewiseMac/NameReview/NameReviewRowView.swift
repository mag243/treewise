import AppKit
import TreewiseCore
import TreewiseUI

/// One file in the overview's list: two lines, the original above the new name, in one
/// size and starting at one place, so differences stand out. A name that already fits
/// shows once, as it asks nothing of the user. The selected row edits its name in the
/// window's one name field, and offers its other options and Skip.
@MainActor
final class NameReviewRowView: NSView {
    private static let iconSize: CGFloat = 28
    private static let fittingIconSize: CGFloat = 16
    private static let approvalWidth: CGFloat = 18
    private static let spacing: CGFloat = 8
    private static let sideSpacing: CGFloat = 4
    private static let skippedAlpha: CGFloat = 0.5
    private static let lookOpacity: CGFloat = 0.25
    private static let verticalPadding: CGFloat = 4

    let id: FileItem.ID
    let model: NameReviewModel
    private let nameField: NameReviewField
    private let approval = NSView()
    private let icon = NSImageView()
    private lazy var iconWidth = icon.widthAnchor.constraint(equalToConstant: Self.iconSize)
    private lazy var iconHeight = icon.heightAnchor.constraint(equalToConstant: Self.iconSize)
    private let original = NSTextField(wrappingLabelWithString: "")
    private let newName = NSTextField(wrappingLabelWithString: "")
    private let names = NSStackView()
    private let side = NSStackView()

    /// A row for `id`, which edits its name in `nameField` while selected.
    init(id: FileItem.ID, model: NameReviewModel, nameField: NameReviewField) {
        self.id = id
        self.model = model
        self.nameField = nameField
        super.init(frame: .zero)
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 0
        names.setContentHuggingPriority(.init(1), for: .horizontal)
        for label in [original, newName, nameField.field] {
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        side.spacing = Self.sideSpacing
        side.setContentHuggingPriority(.required, for: .horizontal)
        original.textColor = .secondaryLabelColor
        icon.imageScaling = .scaleProportionallyUpOrDown
        let iconBox = NSView()
        iconBox.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false
        let row = NSStackView(views: [approval, iconBox, names, side])
        row.spacing = Self.spacing
        row.alignment = .centerY
        row.distribution = .fill
        row.edgeInsets = NSEdgeInsets(
            top: Self.verticalPadding, left: 0, bottom: Self.verticalPadding, right: 0)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            approval.widthAnchor.constraint(equalToConstant: Self.approvalWidth),
            // The names of every row start at one place.
            iconBox.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconBox.heightAnchor.constraint(equalToConstant: Self.iconSize),
            icon.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            iconWidth, iconHeight,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Wraps the names at the width the row gives them, and has the list measure the
    /// row's height again when that changes how many lines they take.
    override func layout() {
        super.layout()
        let width = names.frame.width
        var changed = false
        for label in [original, newName, nameField.field]
        where label.preferredMaxLayoutWidth != width {
            label.preferredMaxLayoutWidth = width
            changed = true
        }
        guard changed, let table = enclosingTable else { return }
        let row = table.row(for: self)
        if row >= 0 { table.noteHeightOfRows(withIndexesChanged: [row]) }
    }

    private var enclosingTable: NSTableView? {
        var view = superview
        while let current = view, !(current is NSTableView) { view = current.superview }
        return view as? NSTableView
    }

    /// Shows the row's file as the review has it now.
    func show(isSelected: Bool) {
        guard let entry = model.session?.entry(id) else { return }
        alphaValue = entry.state == .skipped ? Self.skippedAlpha : 1
        showApproval(of: entry)
        let side = entry.restsFitting ? Self.fittingIconSize : Self.iconSize
        icon.image = ItemIcon.image(for: entry.id)
        iconWidth.constant = side
        iconHeight.constant = side
        original.stringValue = entry.originalName
        names.setViews(
            entry.restsFitting ? [original] : [original, newNameView(entry, isSelected)],
            in: .leading)
        self.side.setViews(sideViews(entry, isSelected), in: .leading)
    }

    // MARK: - Approval

    private func showApproval(of entry: NameProposalSession.Entry) {
        for view in approval.subviews { view.removeFromSuperview() }
        let view: NSView
        if entry.restsFitting {
            let check = NSImageView(
                image: NSImage(
                    systemSymbolName: "checkmark",
                    accessibilityDescription: String(localized: "Already fits")) ?? NSImage())
            check.contentTintColor = .systemGreen
            check.toolTip = String(localized: "Already fits")
            view = check
        } else if !entry.isOutOfScope {
            let model = model
            let id = id
            let box = ClosureCheckbox(title: "") { approved in
                if approved { model.approve(id) } else { model.undecide(id) }
            }
            box.setAccessibilityLabel(String(localized: "Approve"))
            box.state = entry.state == .approved ? .on : .off
            view = box
        } else {
            return
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        approval.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: approval.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: approval.centerYAnchor),
            approval.heightAnchor.constraint(greaterThanOrEqualTo: view.heightAnchor),
        ])
    }

    // MARK: - The new name

    private func newNameView(_ entry: NameProposalSession.Entry, _ isSelected: Bool) -> NSView {
        let name = entry.currentName ?? ""
        if isSelected, !entry.isOutOfScope {
            nameField.show(
                name, placeholder: emptyText(entry),
                marks: model.fieldMarks(of: entry.id).map {
                    ColoredRange(range: NSRange($0.range, in: name), colorIndex: $0.colorIndex)
                },
                lookMarks: lookMarks(in: name, entry))
            let model = model
            let id = id
            nameField.onChange = { model.edit(id, to: $0) }
            nameField.onFinish = { model.finishEditing(id) }
            nameField.onStep =
                (entry.position?.count ?? 0) > 1
                ? { direction in
                    model.step(id, by: direction)
                    return model.session?.entry(id)?.currentName
                } : nil
            return nameField.field
        }
        if let current = entry.currentName {
            newName.attributedStringValue = marked(current, entry)
            newName.textColor = model.conflicts[entry.id] == nil ? .labelColor : .systemRed
        } else {
            newName.attributedStringValue = NSAttributedString(
                string: emptyText(entry),
                attributes: [
                    .font: NSFontManager.shared.convert(
                        .systemFont(ofSize: NSFont.systemFontSize), toHaveTrait: .italicFontMask),
                    .foregroundColor: NSColor.tertiaryLabelColor,
                ])
        }
        return newName
    }

    private func emptyText(_ entry: NameProposalSession.Entry) -> String {
        if entry.isOutOfScope { return String(localized: "Not for these add-ons. Stays as it is.") }
        return model.readingCount > 0
            ? String(localized: "Reading the file…")
            : String(localized: "No proposal. Type a name.")
    }

    /// The gap, or the date of a name whose date needs a look, for the field being edited.
    private func lookMarks(in name: String, _ entry: NameProposalSession.Entry) -> [ColoredRange] {
        let text = name as NSString
        let gap = text.range(of: NameTemplate.gap)
        if gap.location != NSNotFound { return [ColoredRange(range: gap, tint: .gap)] }
        guard entry.currentDateSource != nil else { return [] }
        let date = text.range(of: Self.dateText(in: name))
        return date.location == NSNotFound || date.length == text.length
            ? [] : [ColoredRange(range: date, tint: .dateToCheck)]
    }

    /// Colours a gap, and the date of a name whose date needs a look.
    private func marked(_ name: String, _ entry: NameProposalSession.Entry) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: name, attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)])
        let gap = (name as NSString).range(of: NameTemplate.gap)
        if gap.location != NSNotFound {
            text.addAttribute(
                .backgroundColor,
                value: NSColor.controlAccentColor.withAlphaComponent(Self.lookOpacity), range: gap)
        } else if entry.currentDateSource != nil {
            let date = (name as NSString).range(of: Self.dateText(in: name))
            if date.location != NSNotFound {
                text.addAttribute(
                    .backgroundColor,
                    value: NSColor.systemOrange.withAlphaComponent(Self.lookOpacity), range: date)
            }
        }
        return text
    }

    private static func dateText(in name: String) -> String {
        name.range(of: "[0-9]{2,4}[.-][0-9]{2}[.-][0-9]{2,4}|[0-9]{8}", options: .regularExpression)
            .map { String(name[$0]) } ?? name
    }
}
