import Observation
import TreewiseCore
import TreewiseUI

/// The proposals for one file being renamed (ADR 0066, 0130): asked of the folder's
/// add-ons as a review of that file alone, as the Mac's suggestion list asks them.
@MainActor
@Observable
final class NameProposalsAsked {
    enum State: Equatable {
        case notAsked
        case reading
        /// The proposals, or none with why.
        case answered
    }

    private(set) var state = State.notAsked
    private(set) var options: [NameOption] = []
    /// Why there are no proposals, once answered with none.
    private(set) var note: String?
    /// The proposal last put in the field by ↑ or ↓.
    private(set) var highlighted: Int?
    private var model: NameReviewModel?

    func ask(for item: FileItem, in browser: BrowserState) async {
        guard state == .notAsked else { return }
        state = .reading
        guard
            let model = await browser.makeNameProposals(
                for: item, host: NameServices.moduleHost, store: NameServices.folderSettings)
        else {
            answer([], note: String(localized: "No proposal."))
            return
        }
        self.model = model
        await model.start()
        await model.waitUntilRead()
        let options = model.options(of: item.id)
        answer(options, note: options.isEmpty ? Self.note(for: model.session?.entry(item.id)) : nil)
    }

    /// Moves the highlight by `offset`, from the start when there is none, and gives the
    /// proposal it lands on.
    func step(by offset: Int) -> NameOption? {
        guard !options.isEmpty else { return nil }
        let start = highlighted ?? (offset > 0 ? -1 : options.count)
        let index = min(max(start + offset, 0), options.count - 1)
        highlighted = index
        return options[index]
    }

    func stop() {
        model?.stop()
    }

    private func answer(_ options: [NameOption], note: String?) {
        self.options = options
        self.note = note
        highlighted = nil
        state = .answered
    }

    /// Why a file got no proposal, as the Mac's list says it.
    private static func note(for entry: NameProposalSession.Entry?) -> String {
        if entry?.isOutOfScope == true { return String(localized: "Not for these add-ons.") }
        if entry?.restsFitting == true { return String(localized: "This name already fits.") }
        return String(localized: "No proposal.")
    }
}
