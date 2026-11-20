import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Settings' Templates tab: the list, renaming, deleting, importing, and editing a tree, each
/// saved at once with Undo (ADR 0091, ADR 0095).
@MainActor
@Suite struct FolderTemplatesModelTests {
    private static let year = FolderTemplate(
        id: "year", name: "Household Year",
        root: FolderTree(name: "{year}", folders: [FolderTree(name: "Tax")]))
    private static let client = FolderTemplate(
        id: "client", name: "Client", root: FolderTree(name: "{text}"))

    private let store = MemoryFolderTemplates([year, client])
    private let undoManager = UndoManager()

    private func model() async -> FolderTemplatesModel {
        let model = FolderTemplatesModel(store: store)
        await model.load()
        return model
    }

    @Test func listsTheTemplatesByName() async {
        #expect(await model().templates.map(\.name) == ["Client", "Household Year"])
    }

    @Test func renamesATemplateAndUndoesIt() async {
        let model = await model()
        await model.rename("year", to: "Year", undoManager: undoManager)
        #expect(await store.templates().map(\.name) == ["Client", "Year"])
        undoManager.undo()
        #expect(await eventually { model.templates.map(\.name) == ["Client", "Household Year"] })
    }

    @Test func undoesTwoChangesInTurnAndRedoesTheLast() async {
        let model = await model()
        await model.rename("year", to: "Year", undoManager: undoManager)
        await model.rename("year", to: "Year 2", undoManager: undoManager)
        undoManager.undo()
        #expect(await eventually { model.templates.map(\.name) == ["Client", "Year"] })
        undoManager.undo()
        #expect(await eventually { model.templates.map(\.name) == ["Client", "Household Year"] })
        #expect(undoManager.canRedo)
        undoManager.redo()
        #expect(await eventually { model.templates.map(\.name) == ["Client", "Year"] })
    }

    @Test func refusesAnEmptyNameOrOneAnotherTemplateHas() async {
        let model = await model()
        await model.rename("year", to: "  ", undoManager: undoManager)
        #expect(model.problem == .emptyName)
        await model.rename("year", to: "Client", undoManager: undoManager)
        #expect(model.problem == .nameTaken("Client"))
        #expect(await store.templates().map(\.name) == ["Client", "Household Year"])
    }

    @Test func deletesATemplateAtOnceAndUndoesIt() async {
        let model = await model()
        await model.delete("year", undoManager: undoManager)
        #expect(model.templates.map(\.id) == ["client"])
        undoManager.undo()
        #expect(await eventually { model.templates.map(\.id) == ["client", "year"] })
    }

    @Test func addsAFolderToATreeAndUndoesIt() async throws {
        let model = await model()
        let path = await model.addFolder(
            in: [], of: "year", named: "untitled folder", undoManager: undoManager)
        #expect(path == ["untitled folder"])
        let saved = await store.templates().first { $0.id == "year" }
        #expect(saved?.root.folders.map(\.name) == ["Tax", "untitled folder"])
        undoManager.undo()
        #expect(
            await eventually {
                model.templates.first { $0.id == "year" }?.root.folders.map(\.name) == ["Tax"]
            })
    }

    @Test func removesTheNameSettingsOfAFolderAndUndoesIt() async throws {
        let names = FolderNameSettings(enabledModules: ["free"], moduleOrder: [], patterns: [:])
        let withNames = FolderTemplate(
            id: "names", name: "Named",
            root: FolderTree(name: "{year}", folders: [FolderTree(name: "Tax", names: names)]))
        let store = MemoryFolderTemplates([withNames])
        let model = FolderTemplatesModel(store: store)
        await model.load()
        await model.removeNames(at: ["Tax"], of: "names", undoManager: undoManager)
        let saved = await store.templates().first
        #expect(saved?.root.folder(at: ["Tax"])?.names == nil)
        undoManager.undo()
        #expect(
            await eventually { model.templates.first?.root.folder(at: ["Tax"])?.names == names })
    }

    @Test func addsTheMissingFoldersToATemplateAndUndoesIt() async throws {
        let model = await model()
        let made = FolderTree(
            name: "2027",
            folders: [FolderTree(name: "Tax"), FolderTree(name: "Receipts")])
        let recognized = FolderTree(
            name: "{year}",
            folders: [FolderTree(name: "Tax"), FolderTree(name: "Receipts")])
        let missing = MissingFolders(
            of: made, in: FolderContents(folders: ["Tax": FolderContents()]))
        await model.addMissing(
            missing, from: recognized, year: 2027, to: "year", undoManager: undoManager)
        let saved = await store.templates().first { $0.id == "year" }
        #expect(saved?.root.folders.map(\.name) == ["Receipts", "Tax"])
        #expect(undoManager.undoActionName == "Add to Template")
        undoManager.undo()
        #expect(await eventually { model.templates.first { $0.id == "year" } == Self.year })
    }

    @Test func duplicatesATemplateUnderTheNextFreeNameAndUndoesIt() async throws {
        let model = await model()
        let copy = try #require(await model.duplicate("year", undoManager: undoManager))
        let made = try #require(model.templates.first { $0.id == copy })
        #expect(made.name == "Household Year 2")
        #expect(made.root == Self.year.root)
        #expect(copy != "year", "the copy has an id of its own")
        undoManager.undo()
        #expect(await eventually { !model.templates.contains { $0.id == copy } })
    }

    @Test func refusesAnEditTheTreeCannotTakeAndSaysWhy() async {
        let model = await model()
        await model.renameFolder(["Tax"], of: "year", to: "{seq}", undoManager: undoManager)
        #expect(model.problem == .tree(.numberBelowTop("{seq}")))
        #expect(model.templates.first { $0.id == "year" } == Self.year)
    }

    @Test func importsAFileWithoutAnIDAsANewTemplate() async throws {
        let model = await model()
        let json = #"{"format": 1, "name": "Client", "root": {"name": "{text}", "folders": []}}"#
        #expect(await model.importTemplate(from: Data(json.utf8)) == .imported)
        #expect(model.templates.map(\.name) == ["Client", "Client 2", "Household Year"])
        #expect(Set(model.templates.map(\.id)).count == 3, "under an id of its own")
    }

    @Test func saysWhenAFileIsNoTemplate() async {
        let model = await model()
        await model.importTemplate(from: Data("nope".utf8))
        #expect(model.problem == .file(.unreadable))
    }

    @Test func savesAFoldersStructureAsANewTemplateOrInPlaceOfOneOfTheSameName() async {
        let model = await model()
        #expect(model.template(named: "Household Year")?.id == "year")
        let tree = FolderTree(name: "{year}", folders: [FolderTree(name: "Bank")])
        await model.save(tree, as: "Household Year")
        #expect(model.templates.count == 2)
        #expect(model.templates.first { $0.id == "year" }?.root == tree)
        await model.save(tree, as: "Another")
        #expect(model.templates.map(\.name) == ["Another", "Client", "Household Year"])
    }
}
