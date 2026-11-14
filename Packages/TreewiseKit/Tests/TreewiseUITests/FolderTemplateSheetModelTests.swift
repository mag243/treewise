import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// The sheet of New Folders from Template (ADR 0091, ADR 0095 to ADR 0097).
@MainActor
@Suite struct FolderTemplateSheetModelTests {
    private static let addOn = AddOnDescription(id: "templates", kind: .folderStructure)
    private static let year = FolderTree(
        name: "{year}", folders: [FolderTree(name: "Summary {year}"), FolderTree(name: "Tax")])
    private static let client = FolderTree(
        name: "P-{seq:0001-} {text}", folders: [FolderTree(name: "Contract")])
    private static let today = FolderTemplateValues.Day(year: 2026, month: 11, day: 14)

    private let host = ScriptedModuleHost(modules: [addOn], answers: [:])
    private let fileSystem = ChangingFileSystem()

    /// A folder whose id is its path, as on disk, so the year in it counts.
    @discardableResult
    private func folder(_ path: String) async throws -> FileItem {
        let parts = path.split(separator: "/").map(String.init)
        var parent: FileItem.ID = "documents"
        var made: FileItem?
        for index in parts.indices {
            let id = FileItem.ID("/v/" + parts[...index].joined(separator: "/"))
            if let there = try? await fileSystem.item(at: id) {
                made = there
            } else {
                let item = FileItem(
                    id: id, name: parts[index], kind: .folder, parentID: parent, volume: "v")
                fileSystem.add(item)
                made = item
            }
            parent = id
        }
        return try #require(made)
    }

    private func sheet(_ template: FolderTree, _ place: FolderTemplateSheetModel.Place) async
        -> FolderTemplateSheetModel
    {
        let sheet = FolderTemplateSheetModel(
            template: template, place: place, fileSystem: fileSystem,
            asking: .init(host: host, moduleID: Self.addOn.id, licence: { .none }),
            currentYear: 2026, today: Self.today, language: .english)
        await sheet.start()
        return sheet
    }

    @Test func proposesTheYearAfterACompleteOneAndShowsTheTreeForIt() async throws {
        try await folder("Household/2026/Summary 2026")
        try await folder("Household/2026/Tax")
        let sheet = await sheet(Self.year, .inside("/v/Household"))
        #expect(sheet.fields == [.year])
        #expect(sheet.values.year == 2027)
        #expect(sheet.entries.map(\.path.last) == ["2027", "Summary 2027", "Tax"])
        #expect(sheet.canCreate)
    }

    @Test func proposesTheHighestYearWhileItLacksFoldersAndShowsWhatIsThere() async throws {
        try await folder("Household/2026/Summary 2026")
        try await folder("Household/2026/Tax")
        try await folder("Household/2027/Tax")
        let sheet = await sheet(Self.year, .inside("/v/Household"))
        #expect(sheet.values.year == 2027)
        #expect(sheet.entries.map(\.state) == [.existing, .new, .existing])
        #expect(sheet.toMakeCount == 1)
    }

    @Test func theTreeFollowsTheYearTyped() async throws {
        try await folder("Household")
        let sheet = await sheet(Self.year, .inside("/v/Household"))
        await sheet.setYear(2030)
        #expect(sheet.entries.map(\.path.last) == ["2030", "Summary 2030", "Tax"])
    }

    @Test func proposesTheNextNumberAndWaitsForTheText() async throws {
        try await folder("Clients/P-0142 Smit")
        let sheet = await sheet(Self.client, .inside("/v/Clients"))
        #expect(sheet.fields == [.number, .text])
        #expect(sheet.values.number == FolderTemplateValues.Number(value: 143, width: 4))
        #expect(sheet.problem == .textNeeded)
        #expect(!sheet.canCreate)
        await sheet.setText("Acme")
        #expect(sheet.tree?.name == "P-0143 Acme")
        #expect(sheet.canCreate)
    }

    @Test func saysWhyATextCannotBeAFoldersName() async throws {
        try await folder("Clients")
        let sheet = await sheet(Self.client, .inside("/v/Clients"))
        await sheet.setText("a/b")
        #expect(sheet.problem == .tree(.invalidName("P-0001 a/b")))
        #expect(!sheet.canCreate)
    }

    @Test func fillsAYearsFolderItselfWithoutAskingTheYear() async throws {
        let year = try await folder("Household/2027")
        let sheet = await sheet(Self.year, .filling(year))
        #expect(sheet.fields.isEmpty)
        #expect(
            sheet.entries.map(\.path) == [["2027"], ["2027", "Summary 2027"], ["2027", "Tax"]])
        #expect(sheet.entries.first?.state == .existing)
        #expect(sheet.folderMadeIn == "/v/Household")
    }

    @Test func takesTheYearOfTheFoldersPathDeeperDown() async throws {
        let tax = try await folder("Household/2027/Tax")
        let template = FolderTree(name: "Tax", folders: [FolderTree(name: "Returns {year}")])
        let sheet = await sheet(template, .filling(tax))
        #expect(sheet.fields.isEmpty)
        #expect(sheet.tree?.folders.map(\.name) == ["Returns 2027"])
    }

    @Test func fillsAClientsFolderUnderItsOwnNameWithoutItsNumber() async throws {
        let acme = try await folder("Clients/Acme")
        let sheet = await sheet(Self.client, .filling(acme))
        #expect(sheet.fields.isEmpty)
        #expect(sheet.tree?.name == "Acme")
        #expect(sheet.toMakeCount == 1)
    }

    @Test func showsNothingToMakeWhileTheAddOnGivesNothing() async throws {
        try await folder("Household")
        let other = ScriptedModuleHost(modules: [], answers: [:])
        let sheet = FolderTemplateSheetModel(
            template: Self.year, place: .inside("/v/Household"), fileSystem: fileSystem,
            asking: .init(host: other, moduleID: "templates", licence: { .none }),
            currentYear: 2026, today: Self.today)
        await sheet.start()
        #expect(sheet.problem == .addOnGaveNothing)
        #expect(!sheet.canCreate)
    }
}

/// Create Folders from the window, as one step for Undo (ADR 0091).
@MainActor
@Suite struct BrowserStateFolderTemplateTests {
    let fileSystem = ChangingFileSystem()

    @Test func makesATemplatesFoldersAndUndoesThemAtOnce() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")
        let undoManager = UndoManager()
        let tree = FolderTree(
            name: "2027", folders: [FolderTree(name: "Receipts"), FolderTree(name: "Tax")])
        let outcome = await browser.createFolders(
            making: tree, in: "documents", undoManager: undoManager)
        #expect(outcome?.madeCount == 3)
        #expect(browser.focusedNames.contains("2027"))
        #expect(undoManager.undoActionName == "New Folders from Template")

        undoManager.undo()
        #expect(await eventually { !browser.focusedNames.contains("2027") })
    }
}
