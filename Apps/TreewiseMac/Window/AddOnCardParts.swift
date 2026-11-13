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
    private static let edge: CGFloat = 0.32
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

    /// `label` on a light fill of `color`, as a badge or a field's label.
    static func pill(_ label: NSTextField, color: NSColor, edged: Bool = false) -> NSBox {
        let box = group(
            fill: color.withAlphaComponent(tint),
            border: edged ? color.withAlphaComponent(edge) : .clear, radius: pillRadius)
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
        return legend
    }
}

/// The fields an add-on recognizes, each as a label with its example, wrapped over as
/// many lines as `width` needs (ADR 0092).
@MainActor
final class RecognizedFieldsView: NSView {
    private static let spacing: CGFloat = 5
    private let height: CGFloat

    override var isFlipped: Bool { true }

    init(_ fields: [RecognizedField], width: CGFloat) {
        var placed: [(NSView, NSRect)] = []
        var origin = NSPoint.zero
        var lineHeight: CGFloat = 0
        for field in fields {
            let label = NSTextField(labelWithAttributedString: Self.text(of: field))
            let pill = AddOnCardStyle.pill(
                label, color: AddOnCardStyle.color(of: field.kind), edged: true)
            let size = pill.fittingSize
            if origin.x > 0, origin.x + size.width > width {
                origin = NSPoint(x: 0, y: origin.y + lineHeight + Self.spacing)
                lineHeight = 0
            }
            placed.append((pill, NSRect(origin: origin, size: size)))
            origin.x += size.width + Self.spacing
            lineHeight = max(lineHeight, size.height)
        }
        height = origin.y + lineHeight
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        for (pill, frame) in placed {
            pill.frame = frame
            addSubview(pill)
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

    private static func text(of field: RecognizedField) -> NSAttributedString {
        let size = NSFont.preferredFont(forTextStyle: .caption1).pointSize
        let text = NSMutableAttributedString(
            string: field.token,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: size, weight: .medium),
                .foregroundColor: AddOnCardStyle.color(of: field.kind),
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
