import AppKit
import TreewiseModuleInterface

/// The words for a licence's state (ADR 0071).
enum LicenceText {
    static func state(_ state: ModuleLicenceState) -> String {
        switch state {
        case .licensed(let licensee): String(localized: "Licensed to \(licensee)")
        case .trial(let days): String(localized: "Trial: \(days) days left")
        case .unlicensed: String(localized: "Needs a licence")
        }
    }

    /// Opens the page where an add-on is bought.
    static func buy(_ module: NameModuleDescription) {
        guard let page = module.purchaseURL.flatMap(URL.init(string:)) else { return }
        NSWorkspace.shared.open(page)
    }
}
