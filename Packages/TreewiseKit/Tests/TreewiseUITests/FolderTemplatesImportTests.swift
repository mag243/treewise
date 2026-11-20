import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Import keeps a template's id, so folders made from it on another Mac find it, and asks
/// what to do with a template that is here already (ADR 0141).
@MainActor
@Suite struct FolderTemplatesImportTests {
    private static let year = FolderTemplate(
        id: "year", name: "Household Year",
        root: FolderTree(name: "{year}", folders: [FolderTree(name: "Tax")]))
    /// The same template, as another Mac changed it.
    private static let changed = FolderTemplate(
        id: "year", name: "Household Year",
        root: FolderTree(
            name: "{year}", folders: [FolderTree(name: "Tax"), FolderTree(name: "Bank")]))

    private let undoManager = UndoManager()

    private func model() async -> FolderTemplatesModel {
        let model = FolderTemplatesModel(store: MemoryFolderTemplates([Self.year]))
        await model.load()
        return model
    }

    @Test func keepsTheFilesIDWhenNoTemplateHereHasIt() async throws {
        let model = await model()
        let other = FolderTemplate(id: "club", name: "Club Year", root: FolderTree(name: "{year}"))
        #expect(
            await model.importTemplate(from: try FolderTemplateFile.data(of: other)) == .imported)
        #expect(model.templates.map(\.id).contains("club"))
    }

    @Test func asksAboutATemplateThatIsHereAlready() async throws {
        let model = await model()
        let result = await model.importTemplate(from: try FolderTemplateFile.data(of: Self.changed))
        #expect(result == .sameTemplate(here: Self.year, file: Self.changed))
        #expect(model.templates == [Self.year], "nothing changes before the user chooses")
    }

    @Test func replaceKeepsTheIDAndUndoes() async throws {
        let model = await model()
        await model.replace(withImported: Self.changed, undoManager: undoManager)
        #expect(model.templates == [Self.changed])
        undoManager.undo()
        #expect(await eventually { model.templates == [Self.year] })
    }

    @Test func keepBothGivesTheCopyAnIDAndANameOfItsOwn() async {
        let model = await model()
        await model.keepBoth(Self.changed)
        #expect(model.templates.count == 2)
        let copy = model.templates.first { $0.id != "year" }
        #expect(copy?.name == "Household Year 2")
        #expect(copy?.root == Self.changed.root)
    }
}
