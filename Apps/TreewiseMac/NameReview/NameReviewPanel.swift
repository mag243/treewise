import AppKit
import TreewiseCore
import TreewiseUI

/// The panel beside the list, about the selected row: the file, what needs a look, where
/// the name comes from, and the names around it. It stays in view while the list scrolls.
@MainActor
final class NameReviewPanel: NSObject {
    private static let previewHeight: CGFloat = 200
    private static let padding: CGFloat = 12
    private static let spacing: CGFloat = 10
    private static let neighbourSpacing: CGFloat = 3
    private static let neighbourRadius: CGFloat = 3
    private static let newOpacity: CGFloat = 0.2

    private let model: NameReviewModel
    private let preview = QuickLookView()
    private let stack = NSStackView()
    /// The width of the text in the panel.
    private var textWidth: CGFloat = 0

    init(model: NameReviewModel) {
        self.model = model
        super.init()
    }

    /// The panel in a scroll view of `width`.
    func makeView(width: CGFloat) -> NSView {
        textWidth = width - Self.padding * 2
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedView()
        document.addSubview(stack)
        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        document.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: width),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            preview.heightAnchor.constraint(equalToConstant: Self.previewHeight),
            preview.widthAnchor.constraint(equalToConstant: textWidth),
        ])
        Observing.follow(self) { $0.update() }
        return scroll
    }

    private func update() {
        guard let entry = model.selectedID.flatMap({ model.session?.entry($0) }) else {
            stack.setViews([], in: .leading)
            return
        }
        preview.show(entry.id)
        var views: [NSView] = [preview]
        views += messages(for: entry)
        views += source(of: entry)
        views.append(neighbours())
        stack.setViews(views, in: .leading)
    }

    private func messages(for entry: NameProposalSession.Entry) -> [NSView] {
        var views: [NSView] = []
        if let conflict = model.conflicts[entry.id] {
            views.append(warning(NameReviewText.text(for: conflict)))
        } else if let problem = entry.problem, let text = NameReviewText.text(for: problem) {
            views.append(warning(text))
        }
        views += entry.personalData.map { warning(NameReviewText.text(for: $0)) }
        if entry.isOutOfScope {
            views.append(caption(String(localized: "Not for these add-ons. Stays as it is.")))
        }
        switch entry.currentDateSource {
        case .fileSystem:
            views.append(warning(String(localized: "Date of the file, check it")))
        case .insideFile where model.isPhoto(entry.id):
            views.append(warning(String(localized: "Date from the photo, check it")))
        case .insideFile:
            views.append(warning(String(localized: "Date from the PDF, check it")))
        case nil:
            break
        }
        return views
    }

    private func source(of entry: NameProposalSession.Entry) -> [NSView] {
        let fitting = NameReviewText.names(ofModules: entry.fittingModuleIDs, in: model)
        if entry.restsFitting { return [caption(String(localized: "Already fits \(fitting)"))] }
        var views: [NSView] = []
        if let from = from(entry) { views.append(caption(String(localized: "From: \(from)"))) }
        if !entry.fittingModuleIDs.isEmpty {
            views.append(caption(String(localized: "Fits \(fitting)")))
        }
        return views
    }

    private func from(_ entry: NameProposalSession.Entry) -> String? {
        guard let index = entry.position?.index else { return nil }
        guard index < entry.proposals.count else { return String(localized: "You") }
        return NameReviewText.names(ofModules: entry.proposals[index].moduleIDs, in: model)
    }

    private func neighbours() -> NSView {
        let title = NSTextField(labelWithString: String(localized: "In This Folder"))
        title.font = .boldSystemFont(
            ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize)
        let list = NSStackView(views: [title])
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = Self.neighbourSpacing
        for neighbour in model.neighbours {
            let name = caption(neighbour.name)
            name.maximumNumberOfLines = 2
            name.textColor = neighbour.isNew ? .labelColor : .secondaryLabelColor
            if neighbour.isNew {
                name.drawsBackground = true
                name.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(
                    Self.newOpacity)
                name.wantsLayer = true
                name.layer?.cornerRadius = Self.neighbourRadius
            }
            list.addArrangedSubview(name)
        }
        return list
    }

    private func warning(_ text: String) -> NSView {
        let icon = NSImageView(
            image: NSImage(
                systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
                ?? NSImage())
        icon.contentTintColor = .systemOrange
        let label = caption(text)
        label.textColor = .systemOrange
        let line = NSStackView(views: [icon, label])
        line.alignment = .firstBaseline
        return line
    }

    private func caption(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = textWidth
        return label
    }
}

/// A view whose origin is at its top left, so a scroll view starts at its top.
@MainActor
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
