import AppKit
import TreewiseCore

/// The badge next to the pointer while dragging: a dot with an arrow for move,
/// a plus for copy or a sign for a refusal, and the text, in a glass capsule
/// with a shadow.
@MainActor
final class DragBadgeView: NSView {
    private static let dotSize: CGFloat = 18
    private static let symbolSize: CGFloat = 9
    private static let fontSize: CGFloat = 12
    private static let spacing: CGFloat = 6
    private static let leading: CGFloat = 5
    private static let trailing: CGFloat = 10
    private static let vertical: CGFloat = 4
    private static let shadowRadius: CGFloat = 9
    private static let shadowOffset: CGFloat = 6
    private static let shadowOpacity: Float = 0.16
    /// Room around the capsule for its shadow inside the panel.
    private static let margin: CGFloat = 12

    private let row = NSStackView()
    private lazy var capsule = GlassSurface(
        content: row, material: .popover, blendingMode: .behindWindow, outlined: true)
    private let dot = NSView()
    private let symbol = NSImageView()
    private let label = NSTextField(labelWithString: "")
    /// The mode shown; `nil` for a refusal.
    private var mode: TransferMode??

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = Self.shadowOpacity
        layer?.shadowRadius = Self.shadowRadius
        layer?.shadowOffset = CGSize(width: 0, height: -Self.shadowOffset)
        dot.wantsLayer = true
        dot.layer?.cornerRadius = Self.dotSize / 2
        symbol.contentTintColor = .white
        symbol.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .heavy)
        label.font = .systemFont(ofSize: Self.fontSize, weight: .medium)
        label.lineBreakMode = .byClipping
        layOut()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func layOut() {
        row.setViews([dot, label], in: .leading)
        row.spacing = Self.spacing
        row.edgeInsets = NSEdgeInsets(
            top: Self.vertical, left: Self.leading, bottom: Self.vertical, right: Self.trailing)
        for view in [capsule, symbol] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        addSubview(capsule)
        dot.addSubview(symbol)
        let margin = Self.margin
        NSLayoutConstraint.activate([
            capsule.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            capsule.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
            capsule.topAnchor.constraint(equalTo: topAnchor, constant: margin),
            capsule.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -margin),
            dot.widthAnchor.constraint(equalToConstant: Self.dotSize),
            dot.heightAnchor.constraint(equalToConstant: Self.dotSize),
            symbol.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
        ])
    }

    /// Shows `text` with the sign of `mode`, or of a refusal when `nil`.
    func show(_ mode: TransferMode?, text: String) {
        if label.stringValue != text { label.stringValue = text }
        guard self.mode != .some(mode) else { return }
        self.mode = .some(mode)
        let name =
            switch mode {
            case .move: "arrow.right"
            case .copy: "plus"
            case nil: "nosign"
            }
        symbol.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        needsDisplay = true
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        let color: NSColor =
            switch mode {
            case .some(.move): .controlAccentColor
            case .some(.copy): .systemGreen
            default: .systemRed
            }
        dot.layer?.backgroundColor = color.cgColor
    }

    override func layout() {
        super.layout()
        capsule.cornerRadius = capsule.bounds.height / 2
    }
}
