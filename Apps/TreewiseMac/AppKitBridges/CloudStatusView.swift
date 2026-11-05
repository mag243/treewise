import AppKit

/// What a file's row or tile shows of its place in the cloud (ADR 0051): a
/// cloud with a download arrow, as in Finder, for a file kept only online, a
/// ring while it downloads, and nothing for a file on this Mac.
final class CloudStatusView: NSView {
    private static let symbolSize: CGFloat = 13
    /// The view's size, which leaves room for the symbol's width.
    private static let size: CGFloat = 18

    private let cloud = NSImageView()
    private let ring = NSProgressIndicator()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let label = String(localized: "Only online", comment: "A file's cloud status")
        let image = NSImage(
            systemSymbolName: "icloud.and.arrow.down", accessibilityDescription: label)
        cloud.image = image?.withSymbolConfiguration(
            .init(pointSize: Self.symbolSize, weight: .regular))
        cloud.contentTintColor = .secondaryLabelColor
        cloud.toolTip = label
        cloud.setAccessibilityLabel(label)
        ring.style = .spinning
        ring.controlSize = .small
        ring.minValue = 0
        ring.maxValue = 1
        ring.toolTip = String(localized: "Downloading", comment: "A file's cloud status")
        ring.setAccessibilityLabel(ring.toolTip)
        var constraints = [
            widthAnchor.constraint(equalToConstant: Self.size),
            heightAnchor.constraint(equalToConstant: Self.size),
        ]
        for view in [cloud, ring] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            constraints += [
                view.centerXAnchor.constraint(equalTo: centerXAnchor),
                view.centerYAnchor.constraint(equalTo: centerYAnchor),
            ]
        }
        NSLayoutConstraint.activate(constraints)
        show(isOnlyOnline: false, download: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("CloudStatusView is made in code only")
    }

    /// Shows the ring at `download`, the fraction done, or the cloud. A
    /// download that reports nothing yet spins.
    func show(isOnlyOnline: Bool, download: Double?) {
        isHidden = !isOnlyOnline && download == nil
        cloud.isHidden = !isOnlyOnline || download != nil
        ring.isHidden = download == nil
        let isIndeterminate = download.map { $0 <= 0 } ?? false
        ring.isIndeterminate = isIndeterminate
        ring.doubleValue = download ?? 0
        if isIndeterminate {
            ring.startAnimation(nil)
        } else {
            ring.stopAnimation(nil)
        }
    }
}
