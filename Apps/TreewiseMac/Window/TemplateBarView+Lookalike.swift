import AppKit
import TreewiseCore
import TreewiseUI

/// The bar's question about a missing folder nearly named as one there (ADR 0139):
/// `“Belastingsdienst” in 2025 looks like “Belastingdienst” in 2026.` with Rename in 2025
/// to “Belastingdienst”, Rename in 2026 to “Belastingsdienst” and Add Anyway, the name in
/// the most years first.
extension TemplateBarView {
    /// The most years a label names one by one; more are named by their first and last.
    private static let yearsListed = 3

    func show(_ lookalike: TemplateBarModel.Lookalike) {
        create.isHidden = true
        label.stringValue = String(
            localized:
                "“\(lookalike.missingName)” in \(Self.years(lookalike.missingYears)) looks like “\(lookalike.presentName)” in \(Self.years(lookalike.presentYears))."
        )
        let toPresent = Self.rename(
            lookalike.missingYears, to: lookalike.presentName)
        let toMissing = Self.rename(lookalike.presentYears, to: lookalike.missingName)
        firstName.title = lookalike.presentFirst ? toPresent : toMissing
        secondName.title = lookalike.presentFirst ? toMissing : toPresent
        for button in [firstName, secondName, addAnyway] { button.isHidden = false }
    }

    /// `2025`, `2023, 2024 and 2025`, or `2019–2025` for more years.
    private static func years(_ years: [Int]) -> String {
        let names = years.map(String.init)
        guard names.count > yearsListed, let first = names.first, let last = names.last else {
            return names.formatted(.list(type: .and))
        }
        return "\(first)–\(last)"
    }

    private static func rename(_ years: [Int], to name: String) -> String {
        guard years.count == 1, let year = years.first else {
            return String(localized: "Rename in \(years.count) Years to “\(name)”")
        }
        return String(localized: "Rename in \(String(year)) to “\(name)”")
    }

    /// Opens Rename in All Years on a folder with the name being replaced, with the other
    /// name typed in.
    func renameLookalike(first: Bool) {
        guard case .lookalike(let lookalike) = shown, let window else { return }
        let toPresent = first == lookalike.presentFirst
        let folder = toPresent ? lookalike.missingFolder : lookalike.presentFolder
        let name = toPresent ? lookalike.presentName : lookalike.missingName
        Task {
            await RenameInAllYearsSheet.present(
                for: folder, newName: name, browser: browser, on: window,
                undoManager: SharedUndo.manager)
            lookAgain()
        }
    }

    func addLookalikeAnyway() {
        guard case .lookalike(let lookalike) = shown else { return }
        let bar = FolderTemplatesService.bar(for: browser)
        Task {
            await bar.addAnyway(lookalike)
            lookAgain()
        }
    }
}
