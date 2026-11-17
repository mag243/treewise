import AppKit
import TreewiseUI

/// The bar above the review's list that says what kept the review from proposing names:
/// a folder it could not read, add-ons it could not reach, or an add-on that gave no
/// answer. Hidden while nothing is wrong.
@MainActor
final class NameReviewProblemBar {
    /// The room around the bar's contents, as around the review's rows.
    private static let padding: CGFloat = 8
    private static let horizontalPadding: CGFloat = 20

    private let model: NameReviewModel
    private let icon = NSImageView(
        image: NSImage(
            systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
            ?? NSImage())
    private let text = NSTextField(wrappingLabelWithString: "")
    private lazy var retry = ClosureButton(title: String(localized: "Try Again")) { [weak self] in
        self?.tryAgain()
    }
    private let row = NSStackView()

    init(model: NameReviewModel) {
        self.model = model
    }

    func makeView() -> NSView {
        icon.contentTintColor = Tint.problem
        text.textColor = Tint.problem
        text.setAccessibilityIdentifier("reviewProblem")
        // The text takes the room the icon and the button leave, so it starts beside the
        // icon and the button keeps to the trailing edge.
        text.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        retry.controlSize = .small
        row.setViews([icon, text, retry], in: .leading)
        row.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.horizontalPadding, bottom: Self.padding,
            right: Self.horizontalPadding)
        Observing.follow(self) { $0.update() }
        return row
    }

    private func update() {
        let problem = NameReviewText.text(model.startProblem, moduleFailed: model.moduleFailed)
        text.stringValue = problem ?? ""
        row.isHidden = problem == nil
    }

    private func tryAgain() {
        let model = model
        Task { await model.retry() }
    }
}
