import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

/// A template keeps the name settings of each folder and gives them to the folders made from
/// it (ADR 0101).
@Suite struct FolderNameSettingsTests {
    private static let pattern = "{year} Invoice {seq}"
    private static let names = FolderNameSettings(
        enabledModules: ["advanced", "free"], moduleOrder: ["advanced", "free"],
        patterns: ["advanced": pattern])

    private static func reviewed() -> FolderSettings {
        var settings = FolderSettings(
            enabledModules: ["advanced", "free"], templates: ["advanced": pattern])
        settings.moduleOrder = ["advanced", "free"]
        settings.savedPatternLinks = ["advanced": SavedPatternLink(id: "saved", version: 1)]
        settings.alwaysSkipped = ["Overview.numbers"]
        settings.newFolders = .none
        settings.templateBarClosed = true
        return settings
    }

    @Test func keepsTheAddOnsTheirOrderAndPatternsOfAReviewedFolder() throws {
        let names = try #require(FolderNameSettings(Self.reviewed()))
        #expect(names == Self.names)
    }

    @Test func aFolderNeverReviewedHasNone() {
        var settings = FolderSettings(enabledModules: [], templates: [:])
        settings.templateBarClosed = true
        #expect(FolderNameSettings(settings) == nil)
    }

    @Test func givesSettingsWithOnlyTheAddOnsTheCatalogHolds() throws {
        let given = try #require(Self.names.folderSettings(catalog: ["free"]))
        #expect(given.enabledModules == ["free"])
        #expect(given.moduleOrder == ["free"])
        #expect(given.templates.isEmpty)
        #expect(given.savedPatternLinks.isEmpty)
        #expect(given.newFolders == .automatic)
    }

    @Test func givesNothingWhenNoAddOnIsLeft() {
        #expect(Self.names.folderSettings(catalog: ["other"]) == nil)
    }

    @Test func aTreeKeepsItsNamesInItsFile() throws {
        let tree = FolderTree(
            name: "{year}", folders: [FolderTree(name: "Invoices", names: Self.names)])
        let data = try JSONEncoder().encode(tree)
        let read = try JSONDecoder().decode(FolderTree.self, from: data)
        #expect(read.folders.first?.names == Self.names)
        #expect(read.names == nil)
    }

    @Test func aTreeStoredWithoutNamesReads() throws {
        let data = Data(#"{"name":"2026","folders":[{"name":"Tax"}]}"#.utf8)
        let read = try JSONDecoder().decode(FolderTree.self, from: data)
        #expect(read.folders.first?.names == nil)
    }

    @Test func fillingInKeepsTheNamesAndGivesThemToEveryRepeat() {
        let tree = FolderTree(
            name: "{year}", folders: [FolderTree(name: "Q{quarter}", names: Self.names)],
            names: Self.names)
        let made = tree.filling(year: 2027)
        #expect(made.names == Self.names)
        #expect(made.folders.count == 4)
        #expect(made.folders.allSatisfy { $0.names == Self.names })
        #expect(tree.filling(folderNamed: "2027").names == Self.names)
    }

    @Test func editingTheTreeKeepsTheNames() throws {
        let tree = FolderTree(
            name: "{year}",
            folders: [
                FolderTree(name: "Invoices", names: Self.names), FolderTree(name: "Tax"),
            ])
        let renamed = try tree.renaming(["Invoices"], to: "Sales").tree
        #expect(renamed.folder(at: ["Sales"])?.names == Self.names)
        let moved = try renamed.moving(["Sales"], into: ["Tax"]).tree
        #expect(moved.folder(at: ["Tax", "Sales"])?.names == Self.names)
        let added = try moved.adding(in: ["Tax", "Sales"], named: "Paid").tree
        #expect(added.folder(at: ["Tax", "Sales"])?.names == Self.names)
    }

    @Test func removesTheNamesOfOneFolder() {
        let tree = FolderTree(
            name: "{year}", folders: [FolderTree(name: "Invoices", names: Self.names)],
            names: Self.names)
        let removed = tree.removingNames(at: ["Invoices"])
        #expect(removed.folder(at: ["Invoices"])?.names == nil)
        #expect(removed.names == Self.names)
    }

    @Test func listsTheNamesByThePathFromTheRoot() {
        let tree = FolderTree(
            name: "2027",
            folders: [
                FolderTree(
                    name: "Tax", folders: [FolderTree(name: "Returns", names: Self.names)]),
                FolderTree(name: "Receipts"),
            ])
        #expect(tree.namesByPath == [["2027", "Tax", "Returns"]: Self.names])
    }

    @Test func readsTheNamesOfEachFolderWithItsTree() async throws {
        let fileSystem = ChangingFileSystem()
        let documents = try await fileSystem.item(at: "documents")
        let year = try await fileSystem.createFolder(in: documents.id, named: "2026")
        let tax = try await fileSystem.createFolder(in: year.id, named: "Tax")
        _ = try await fileSystem.createFolder(in: year.id, named: "Receipts")
        let tree = try await fileSystem.folderTree(of: year) { folder in
            folder.id == tax.id ? Self.names : nil
        }
        #expect(tree.folder(at: ["Tax"])?.names == Self.names)
        #expect(tree.folder(at: ["Receipts"])?.names == nil)
        #expect(tree.names == nil)
    }

    @Test func givesTheNamesToTheFoldersMadeAndLeavesThoseThereAlone() async throws {
        let fileSystem = ChangingFileSystem()
        let documents = try await fileSystem.item(at: "documents")
        let year = try await fileSystem.createFolder(in: documents.id, named: "2027")
        let tax = try await fileSystem.createFolder(in: year.id, named: "Tax")
        let store = MemoryFolderSettings()
        let own = FolderSettings.new(defaultModuleID: "free")
        await store.save(own, forFolderAt: tax.id.rawValue)
        let tree = FolderTree(
            name: "2027",
            folders: [
                FolderTree(name: "Tax", names: Self.names),
                FolderTree(name: "Invoices", names: Self.names),
            ])
        let outcome = try await fileSystem.createFolders(making: tree, in: documents.id)
        await store.give(namesOf: tree, to: outcome.made, catalog: ["advanced", "free"])
        let invoices = try #require(outcome.made[["2027", "Invoices"]])
        #expect(
            await store.settings(forFolderAt: invoices.rawValue)?.templates == [
                "advanced": Self.pattern
            ])
        #expect(await store.settings(forFolderAt: tax.id.rawValue) == own)
        #expect(outcome.made[["2027", "Tax"]] == nil, "a folder already there was not made")
    }
}
