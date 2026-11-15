import AppKit
import TreewiseModuleInterface
import TreewiseUI

/// The context menu of Settings' add-on cards (ADR 0105): Turn On or Off, Try for 14 Days
/// or Buy…, and Move Up and Down, as far as the card clicked allows.
extension AddOnsSettingsTab {
    func cardMenuItems(for row: Int) -> [NSMenuItem] {
        guard row < shown.count else { return [] }
        let module = shown[row]
        let id = module.id
        let card = addOnCard(for: row)
        var items: [NSMenuItem] = []
        if card.showsSwitch {
            let title = card.isOn ? String(localized: "Turn Off") : String(localized: "Turn On")
            let catalog = catalog
            let settings = settings
            items.append(
                ClosureMenuItem(title, symbol: "power", enabled: card.canSwitch) {
                    settings.addOns.setOn(id, on: !card.isOn, catalog: catalog)
                })
        }
        items += licenceItems(for: module)
        if module.proposesNames {
            if !items.isEmpty { items.append(.separator()) }
            let index = catalog.firstIndex(of: id) ?? row
            let up: () -> Void = { [weak self] in self?.move(id, to: index - 1) }
            let down: () -> Void = { [weak self] in self?.move(id, to: index + 1) }
            items.append(
                ClosureMenuItem(
                    String(localized: "Move Up"), symbol: "arrow.up", enabled: index > 0,
                    handler: up))
            items.append(
                ClosureMenuItem(
                    String(localized: "Move Down"), symbol: "arrow.down",
                    enabled: index < catalog.count - 1, handler: down))
        }
        return items
    }

    /// Try for 14 Days before a paid add-on was tried, and Buy… where it is sold without a
    /// licence, as its card offers them.
    private func licenceItems(for module: AddOnDescription) -> [NSMenuItem] {
        guard let licence = states[module.id] else { return [] }
        var items: [NSMenuItem] = []
        if licence == .notTried {
            let startTrial: () -> Void = { [weak self] in
                self?.licences.startTrial(of: module.id)
                self?.load()
            }
            items.append(
                ClosureMenuItem(
                    TrialText.tryIt, symbol: "clock", handler: startTrial))
        }
        let isLicensed = if case .licensed = licence { true } else { false }
        if !isLicensed, module.purchaseURL != nil {
            items.append(
                ClosureMenuItem(String(localized: "Buy…"), symbol: "cart") {
                    LicenceText.buy(module)
                })
        }
        return items
    }
}
