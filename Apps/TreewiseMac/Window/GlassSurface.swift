import AppKit

/// The background of a small panel that floats over other content, holding
/// that panel's content: Liquid Glass from macOS 26, a blurred material with
/// rounded corners before it.
@MainActor
final class GlassSurface: NSView {
    private let background: NSView
    /// Whether the blurred material gets a hairline edge; glass draws its own.
    private let outlined: Bool

    /// The radius of the corners; half the height makes a capsule.
    var cornerRadius: CGFloat = 0 {
        didSet { applyCornerRadius() }
    }

    /// - Parameters:
    ///   - content: the view shown on the surface, sized to fill it.
    ///   - material: the material before macOS 26.
    ///   - blendingMode: whether that material blurs the window or what is
    ///     behind the window.
    ///   - outlined: whether that material gets a hairline edge.
    init(
        content: NSView, material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode, outlined: Bool = false
    ) {
        self.outlined = outlined
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.contentView = content
            background = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = material
            effect.blendingMode = blendingMode
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.masksToBounds = true
            effect.layer?.borderWidth = outlined ? 1 : 0
            effect.addSubview(content)
            background = effect
        }
        super.init(frame: .zero)
        addSubview(background)
        Self.pin(background, to: self)
        Self.pin(content, to: background)
        applyEdgeColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyEdgeColor()
    }

    /// A layer's colour does not follow the appearance by itself.
    private func applyEdgeColor() {
        guard outlined else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            background.layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    private func applyCornerRadius() {
        if #available(macOS 26, *), let glass = background as? NSGlassEffectView {
            glass.cornerRadius = cornerRadius
        } else {
            background.layer?.cornerRadius = cornerRadius
        }
    }

    private static func pin(_ view: NSView, to container: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
}
