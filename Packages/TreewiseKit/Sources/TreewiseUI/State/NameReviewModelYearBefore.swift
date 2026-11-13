import TreewiseCore
import TreewiseModuleInterface

/// The same folder a year before, as the overview reads it (ADR 0090).
struct YearBefore: Sendable {
    /// The folder's year and the names a year before, as an add-on gets them.
    let years: FolderYears
    /// The names of that folder and those above it, by the keys a template reads them under,
    /// for counting a pattern against its names.
    let folderValues: [String: String]
}

extension NameReviewModel {
    /// The names of the files in the same folder a year before, when the user lets add-ons
    /// read them, one of `descriptions` asks, the folder's path holds a year and that folder
    /// is there; nil otherwise. Hidden files and subfolders are left out, as they are here.
    func readYearBefore(for descriptions: [NameModuleDescription]) async -> YearBefore? {
        guard dependencies.addOns.readsYearBefore,
            descriptions.contains(where: \.readsYearBefore),
            let year = YearFolders.year(of: folder.id),
            let before = YearFolders.folderBefore(folder.id),
            let items = try? await dependencies.operations.contents(of: before)
        else { return nil }
        let names = items.filter { !$0.isHidden && !$0.isContainer }.map(\.name)
        return YearBefore(
            years: FolderYears(year: year, namesYearBefore: names),
            folderValues: NameTemplate.folderValues(NameTemplate.folderNames(of: before)))
    }
}
