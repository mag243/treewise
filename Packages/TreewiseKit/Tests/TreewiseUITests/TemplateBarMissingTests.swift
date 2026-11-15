import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// The folders of the year before a year's folder lacks, offered in its bar and from the
/// menus (ADR 0102).
@MainActor
@Suite struct TemplateBarMissingTests {
    private static let year = FolderTemplate(
        id: "year", name: "Household Year",
        root: FolderTree(name: "{year}", folders: [FolderTree(name: "Receipts")]))

    let fileSystem = ChangingFileSystem()
    let settings = MemoryFolderSettings()
    let templates = MemoryFolderTemplates([year])

    private func model(mayWork: Bool = true, offersMissing: Bool = true) -> TemplateBarModel {
        let fileSystem = fileSystem
        return TemplateBarModel(
            fileSystem: fileSystem, settings: settings, templates: templates,
            addOnMayWork: { mayWork },
            yearBefore: { id in
                // As the add-on reads it: the year as `{year}`.
                guard let folder = try? await fileSystem.item(at: id),
                    let tree = try? await fileSystem.folderTree(of: folder)
                else { return nil }
                return FolderTree(name: FolderTree.yearField, folders: tree.folders)
            },
            offersMissingFolders: { offersMissing })
    }

    /// A folder whose id is its path, as on disk, so the year in it counts.
    @discardableResult
    private func folder(_ name: String, in parent: FileItem.ID) async throws -> FileItem {
        let above = try await fileSystem.item(at: parent)
        let folder = FileItem(
            id: FileItem.ID("\(parent.rawValue)/\(name)"), name: name, kind: .folder,
            parentID: parent, volume: above.volume)
        fileSystem.add(folder)
        return folder
    }

    /// `Household/2026` with Tax/Appeals and Receipts, and `Household/2027` with Receipts.
    private func years() async throws -> (before: FileItem, year: FileItem) {
        let household = try await folder("Household", in: "documents")
        let before = try await folder("2026", in: household.id)
        let tax = try await folder("Tax", in: before.id)
        try await folder("Appeals", in: tax.id)
        try await folder("Receipts", in: before.id)
        let year = try await folder("2027", in: household.id)
        try await folder("Receipts", in: year.id)
        return (before, year)
    }

    @Test func offersTheFoldersOfTheYearBeforeThatTheYearLacks() async throws {
        let (before, year) = try await years()
        let offer = try #require(await model().missing(in: year))
        #expect(offer.yearBefore == before.id)
        #expect(offer.missing.paths == [["Tax"]])
        #expect(offer.missing.tree.folders.map(\.name) == ["Tax"])
    }

    @Test func offersNothingWhenEveryFolderIsThere() async throws {
        let (_, year) = try await years()
        let tax = try await folder("Tax", in: year.id)
        try await folder("Appeals", in: tax.id)
        #expect(await model().missing(in: year) == nil)
        #expect(await model().missing(in: year, all: true) == nil)
    }

    @Test func offersOnlyInAYearsOwnFolder() async throws {
        let (_, year) = try await years()
        let receipts = try await fileSystem.item(at: FileItem.ID("\(year.id.rawValue)/Receipts"))
        #expect(await model().missing(in: receipts, all: true) == nil)
    }

    @Test func offersNothingWhileTheAddOnMayNotWork() async throws {
        let (_, year) = try await years()
        #expect(await model(mayWork: false).missing(in: year) == nil)
        #expect(await model(mayWork: false).missing(in: year, all: true) == nil)
    }

    @Test func theBarLeavesAnEmptyYearToItsOwnBarAndTheMenuDoesNot() async throws {
        let household = try await folder("Household", in: "documents")
        let before = try await folder("2026", in: household.id)
        try await folder("Tax", in: before.id)
        let year = try await folder("2027", in: household.id)
        #expect(await model().missing(in: year) == nil)
        #expect(await model().missing(in: year, all: true)?.missing.paths == [["Tax"]])
    }

    @Test func theSettingTurnsOffOnlyTheBar() async throws {
        let (_, year) = try await years()
        let model = model(offersMissing: false)
        #expect(await model.missing(in: year) == nil)
        #expect(await model.missing(in: year, all: true) != nil)
    }

    @Test func closingLeavesOutTheFoldersMissingThenAndOffersThoseAddedLater() async throws {
        let (before, year) = try await years()
        let model = model()
        let offer = try #require(await model.missing(in: year))
        await model.closeMissing(offer)
        #expect(await model.missing(in: year) == nil)
        try await folder("Budget", in: before.id)
        #expect(await model.missing(in: year)?.missing.paths == [["Budget"]])
        #expect(await model.missing(in: year, all: true)?.missing.paths == [["Budget"], ["Tax"]])
    }

    @Test func dontShowForThisFolderOffersItNoneAtAll() async throws {
        let (before, year) = try await years()
        let model = model()
        await model.offerNoMissing(in: year.id)
        try await folder("Budget", in: before.id)
        #expect(await model.missing(in: year) == nil)
        #expect(await model.missing(in: year, all: true) != nil)
    }

    @Test func offersTheOneYearTemplateWithTheFoldersItLacks() async throws {
        let (_, year) = try await years()
        let offer = try #require(await model().missing(in: year))
        let template = try #require(offer.template)
        #expect(template.id == "year")
        #expect(template.root.folder(at: ["Tax", "Appeals"]) != nil)
        #expect(template.root.folder(at: ["Receipts"]) != nil)
    }

    @Test func offersNoTemplateThatHasTheMissingFolders() async throws {
        let (_, year) = try await years()
        await templates.save(
            FolderTemplate(
                id: "year", name: "Household Year",
                root: FolderTree(
                    name: "{year}",
                    folders: [
                        FolderTree(name: "Tax", folders: [FolderTree(name: "Appeals")])
                    ])))
        #expect(try #require(await model().missing(in: year)).template == nil)
    }
}
