import AppKit
import TreewiseModuleInterface

/// The words for a licence's state (ADR 0071, ADR 0077).
enum LicenceText {
    /// From how many days left a key with an end date counts them down.
    private static let countdownDays = 7

    static func state(_ state: ModuleLicenceState) -> String {
        switch state {
        case .licensed(let licensee, let until): licensed(licensee, until: until, state: state)
        case .trial(let days): String(localized: "Trial: \(days) days left")
        case .unlicensed: String(localized: "Needs a licence")
        }
    }

    private static func licensed(_ licensee: String, until: Date?, state: ModuleLicenceState)
        -> String
    {
        guard let until, let days = state.daysLeft(now: Date(), calendar: .current) else {
            return String(localized: "Licensed to \(licensee)")
        }
        if days <= 1 { return String(localized: "Licensed to \(licensee), until today") }
        if days <= countdownDays {
            return String(localized: "Licensed to \(licensee), \(days) days left")
        }
        let day = until.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "Licensed to \(licensee), until \(day)")
    }

    /// Opens the page where an add-on is bought.
    static func buy(_ module: NameModuleDescription) {
        guard let page = module.purchaseURL.flatMap(URL.init(string:)) else { return }
        NSWorkspace.shared.open(page)
    }
}
