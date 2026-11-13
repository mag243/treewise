import TreewiseCore
import TreewiseModuleInterface

/// The same folder a year before, as the overview reads it (ADR 0090).
struct YearBefore: Sendable {
    /// The folder's year and the names a year before, as an add-on gets them.
    let years: FolderYears
    /// The names of that folder and those above it, by the keys a template reads them under,
    /// for counting a pattern against its names.
    let folderValues: [String: String]
    /// Whether that folder is there; without it the add-on gets the folder's year only.
    let folderFound: Bool
}

extension NameReviewModel {
    /// The folder's year and the names of the files in the same folder a year before, when
    /// the user lets add-ons read them, one of `descriptions` that may work asks, and the
    /// folder's path holds a year; nil otherwise. Without that folder no names are given.
    /// Hidden files and subfolders are left out, as they are here.
    func readYearBefore(for descriptions: [NameModuleDescription]) async -> YearBefore? {
        guard dependencies.addOns.readsYearBefore,
            descriptions.contains(where: { $0.readsYearBefore && mayWork($0.id) }),
            let year = YearFolders.year(of: folder.id),
            let before = YearFolders.folderBefore(folder.id)
        else { return nil }
        let items = try? await dependencies.operations.contents(of: before)
        let names = (items ?? []).filter { !$0.isHidden && !$0.isContainer }.map(\.name)
        return YearBefore(
            years: FolderYears(year: year, namesYearBefore: names),
            folderValues: NameTemplate.folderValues(NameTemplate.folderNames(of: before)),
            folderFound: items != nil)
    }

    /// Whether a module may work: free, licensed or in its trial (ADR 0071, ADR 0088).
    func mayWork(_ id: String) -> Bool {
        licenceStates[id]?.mayWork ?? true
    }

    /// The folder's year and the names a year before, for a module that reads them and may
    /// work (ADR 0090).
    func years(for description: NameModuleDescription) -> FolderYears? {
        description.readsYearBefore && mayWork(description.id) ? yearBefore?.years : nil
    }
}
