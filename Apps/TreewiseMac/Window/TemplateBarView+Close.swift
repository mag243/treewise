import AppKit
import TreewiseCore
import TreewiseUI

/// The menu of the bar's close button (ADR 0097, ADR 0102).
extension TemplateBarView {
    /// For a template's folders, Don't Show for This Folder and Don't Show in the folder
    /// above; for missing folders, Don't Show These Folders and Don't Show for This Folder.
    func closeItems(for shown: Shown) -> [NSMenuItem] {
        let here = String(localized: "Don’t Show for This Folder")
        switch shown {
        case .empty(let offer):
            var items = [
                ClosureMenuItem(here, symbol: "eye.slash") { [weak self] in
                    self?.hide { await $0.close(in: offer.folder.id) }
                }
            ]
            if let above = offer.folder.parentID {
                let inAbove = String(localized: "Don’t Show in \(Self.name(of: above))")
                items.append(
                    ClosureMenuItem(inAbove, symbol: "eye.slash") { [weak self] in
                        self?.hide { await $0.offerNothing(in: above) }
                    })
            }
            return items
        case .lookalike(let lookalike):
            return closeItems(for: .missing(lookalike.offer))
        case .missing(let offer):
            let these = String(localized: "Don’t Show These Folders")
            return [
                ClosureMenuItem(these, symbol: "eye.slash") { [weak self] in
                    self?.hide { await $0.closeMissing(offer) }
                },
                ClosureMenuItem(here, symbol: "eye.slash") { [weak self] in
                    self?.hide { await $0.offerNoMissing(in: offer.folder.id) }
                },
            ]
        }
    }
}
