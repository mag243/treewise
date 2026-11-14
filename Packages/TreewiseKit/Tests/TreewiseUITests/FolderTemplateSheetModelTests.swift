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
    private let none = FolderContents()

    private func sheet(
        _ template: FolderTree, _ place: FolderTemplateSheetModel.Place,
        _ contents: FolderContents
    ) async -> FolderTemplateSheetModel {
        let sheet = FolderTemplateSheetModel(
            template: template, place: place, contents: contents,
            asking: .init(host: host, moduleID: Self.addOn.id, licence: { .none }),
            currentYear: 2026, today: Self.today, language: .english)
        await sheet.refresh()
        return sheet
    }

    @Test func proposesTheYearAfterTheHighestAndShowsTheTreeForIt() async {
        let contents = FolderContents(folders: [
            "2026": FolderContents(folders: ["Summary 2026": none, "Tax": none])
        ])
        let sheet = await sheet(Self.year, .inside("household"), contents)
        #expect(sheet.fields == [.year])
        #expect(sheet.values.year == 2027)
        #expect(sheet.entries.map(\.path.last) == ["2027", "Summary 2027", "Tax"])
        #expect(sheet.canCreate)
    }

    @Test func theTreeFollowsTheYearTyped() async {
        let sheet = await sheet(Self.year, .inside("household"), none)
        await sheet.setYear(2030)
        #expect(sheet.entries.map(\.path.last) == ["2030", "Summary 2030", "Tax"])
    }

    @Test func proposesTheNextNumberAndWaitsForTheText() async {
        let contents = FolderContents(folders: ["P-0142 Smit": none])
        let sheet = await sheet(Self.client, .inside("clients"), contents)
        #expect(sheet.fields == [.number, .text])
        #expect(sheet.values.number == FolderTemplateValues.Number(value: 143, width: 4))
        #expect(sheet.problem == .textNeeded)
        #expect(!sheet.canCreate)
        await sheet.setText("Acme")
        #expect(sheet.tree?.name == "P-0143 Acme")
        #expect(sheet.canCreate)
    }

    @Test func saysWhyATextCannotBeAFoldersName() async {
        let sheet = await sheet(Self.client, .inside("clients"), none)
        await sheet.setText("a/b")
        #expect(sheet.problem == .tree(.invalidName("P-0001 a/b")))
        #expect(!sheet.canCreate)
    }

    @Test func fillsAYearsFolderItselfWithoutAskingTheYear() async {
        let folder = FileItem(
            id: "/v/Household/2027", name: "2027", kind: .folder, parentID: "/v/Household",
            volume: "v")
        let sheet = await sheet(Self.year, .filling(folder), none)
        #expect(sheet.fields.isEmpty)
        #expect(
            sheet.entries.map(\.path) == [["2027"], ["2027", "Summary 2027"], ["2027", "Tax"]])
        #expect(sheet.entries.first?.state == .existing)
        #expect(sheet.folderMadeIn == "/v/Household")
    }

    @Test func fillsAClientsFolderUnderItsOwnNameWithoutItsNumber() async {
        let folder = FileItem(
            id: "/v/Clients/Acme", name: "Acme", kind: .folder, parentID: "/v/Clients",
            volume: "v")
        let sheet = await sheet(Self.client, .filling(folder), none)
        #expect(sheet.fields.isEmpty)
        #expect(sheet.tree?.name == "Acme")
        #expect(sheet.toMakeCount == 1)
    }

    @Test func showsNothingToMakeWhileTheAddOnGivesNothing() async {
        let other = ScriptedModuleHost(modules: [], answers: [:])
        let sheet = FolderTemplateSheetModel(
            template: Self.year, place: .inside("household"), contents: none,
            asking: .init(host: other, moduleID: "templates", licence: { .none }),
            currentYear: 2026, today: Self.today)
        await sheet.refresh()
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
