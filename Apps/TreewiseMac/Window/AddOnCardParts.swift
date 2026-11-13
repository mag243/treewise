import AppKit
import TreewiseCore
import TreewiseUI

/// A switch that reports its state to a closure; it has no title, so it is named for
/// accessibility.
@MainActor
final class ClosureSwitch: NSSwitch {
    private let change: @MainActor (Bool) -> Void

    init(label: String, change: @escaping @MainActor (Bool) -> Void) {
        self.change = change
        super.init(frame: .zero)
        controlSize = .small
        setAccessibilityLabel(label)
        target = self
        action = #selector(changed)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func changed() {
        change(state == .on)
    }
}

/// The look of an add-on's card and its parts (ADR 0092): rounded groups as in System
/// Settings, badges by licence and labels by kind of field.
@MainActor
enum AddOnCardStyle {
    static let cardRadius: CGFloat = 10
    static let pillRadius: CGFloat = 6
    private static let tint: CGFloat = 0.14
    private static let lightFill: CGFloat = 0.75
    private static let darkFill: CGFloat = 0.06
    private static let pillMargins = NSSize(width: 7, height: 2)
    private static let legendMark: CGFloat = 8
    private static let legendSpacing: CGFloat = 12

    /// The fill of a card: lighter than the window, in both appearances.
    static let cardFill = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return NSColor.white.withAlphaComponent(isDark ? darkFill : lightFill)
    }

    /// A rounded group of `fill` with an edge of `border`.
    static func group(
        fill: NSColor, border: NSColor, radius: CGFloat, borderWidth: CGFloat = 1
    ) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.fillColor = fill
        box.borderColor = border
        box.borderWidth = borderWidth
        box.cornerRadius = radius
        box.contentViewMargins = .zero
        return box
    }

    /// `label` on a light fill of `color`, as a badge.
    static func pill(_ label: NSTextField, color: NSColor) -> NSBox {
        let box = group(
            fill: color.withAlphaComponent(tint),
            border: .clear, radius: pillRadius)
        box.contentViewMargins = pillMargins
        box.contentView?.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        if let content = box.contentView {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                label.topAnchor.constraint(equalTo: content.topAnchor),
                label.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }
        return box
    }

    /// The colour of a badge, by the add-on's licence.
    static func color(of tone: AddOnCard.Tone) -> NSColor {
        switch tone {
        case .free: .secondaryLabelColor
        case .licensed: .systemGreen
        case .trial: .systemPurple
        case .notTried: .systemBlue
        case .needsLicence: .systemOrange
        }
    }

    /// The colour of a field's label, by its kind.
    static func color(of kind: RecognizedField.Kind) -> NSColor {
        switch kind {
        case .date: .systemBlue
        case .series: .systemPurple
        case .text: .systemGreen
        case .choice: .systemOrange
        }
    }

    /// The kinds of field, each with its colour, for under the labels.
    static func legend() -> NSView {
        let kinds: [(RecognizedField.Kind, String)] = [
            (.date, String(localized: "Dates")), (.series, String(localized: "Series")),
            (.text, String(localized: "Text")), (.choice, String(localized: "Choice")),
        ]
        let items = kinds.map { kind, name -> NSView in
            let mark = group(fill: color(of: kind), border: .clear, radius: 2)
            mark.widthAnchor.constraint(equalToConstant: legendMark).isActive = true
            mark.heightAnchor.constraint(equalToConstant: legendMark).isActive = true
            let label = NSTextField(labelWithString: name)
            label.font = .preferredFont(forTextStyle: .caption2)
            label.textColor = .secondaryLabelColor
            let item = NSStackView(views: [mark, label])
            item.spacing = 4
            return item
        }
        let legend = NSStackView(views: items)
        legend.spacing = legendSpacing
        legend.distribution = .fill
        legend.setContentHuggingPriority(.required, for: .horizontal)
        return legend
    }
}

/// The fields an add-on recognizes, each as a label with its example, wrapped over as
/// many lines as `width` needs (ADR 0092).
@MainActor
final class RecognizedFieldsView: NSView {
    private static let spacing: CGFloat = 5

    override var isFlipped: Bool { true }

    init(_ fields: [RecognizedField], width: CGFloat) {
        var placed: [(NSView, NSRect)] = []
        var origin = NSPoint.zero
        var lineHeight: CGFloat = 0
        for field in fields {
            let chip = FieldChip(field)
            let size = chip.frame.size
            if origin.x > 0, origin.x + size.width > width {
                origin = NSPoint(x: 0, y: origin.y + lineHeight + Self.spacing)
                lineHeight = 0
            }
            placed.append((chip, NSRect(origin: origin, size: size)))
            origin.x += size.width + Self.spacing
            lineHeight = max(lineHeight, size.height)
        }
        let height = origin.y + lineHeight
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        for (chip, frame) in placed {
            chip.frame = frame
            addSubview(chip)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(
            fields.map { "\($0.token) \($0.example)" }.joined(separator: ", "))
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: height),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

/// One field as a label: the field in the colour of its kind and its example, on a light
/// fill of that colour with an edge. It draws itself and knows its size, so the fields can
/// be placed by frame.
@MainActor
final class FieldChip: NSView {
    private static let margins = NSSize(width: 7, height: 2)
    private static let fill: CGFloat = 0.14
    private static let edge: CGFloat = 0.35
    private let text: NSAttributedString
    private let color: NSColor

    override var isFlipped: Bool { true }

    init(_ field: RecognizedField) {
        color = AddOnCardStyle.color(of: field.kind)
        text = Self.text(of: field, color: color)
        let size = text.size()
        super.init(
            frame: NSRect(
                x: 0, y: 0, width: ceil(size.width) + 2 * Self.margins.width,
                height: ceil(size.height) + 2 * Self.margins.height))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        // Drawn in the view's appearance, so the colours follow light and dark.
        let shape = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: AddOnCardStyle.pillRadius,
            yRadius: AddOnCardStyle.pillRadius)
        color.withAlphaComponent(Self.fill).setFill()
        shape.fill()
        color.withAlphaComponent(Self.edge).setStroke()
        shape.stroke()
        text.draw(at: NSPoint(x: Self.margins.width, y: Self.margins.height))
    }

    private static func text(of field: RecognizedField, color: NSColor) -> NSAttributedString {
        let size = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        let text = NSMutableAttributedString(
            string: field.token,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: size, weight: .medium),
                .foregroundColor: color,
            ])
        if !field.example.isEmpty {
            text.append(
                NSAttributedString(
                    string: "  " + field.example,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: size),
                        .foregroundColor: NSColor.secondaryLabelColor,
                    ]))
        }
        return text
    }
}
