import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Rename in All Years corrects the templates the years were made from, each with its own
/// checkbox, and remembers a template it corrected (ADR 0141).
@MainActor
@Suite struct RenameInAllYearsOriginTests {
    private static func template(_ id: String, _ name: String) -> FolderTemplate {
        FolderTemplate(
            id: id, name: name,
            root: FolderTree(
                name: FolderTree.yearField, folders: [FolderTree(name: "Belastingsdienst")]))
    }
    private static let household = template("household", "Household Year")
    private static let club = template("club", "Club Year")

    let fileSystem = ChangingFileSystem()
    let settings = MemoryFolderSettings()
    let templates = FolderTemplatesModel(
        store: MemoryFolderTemplates([household, club]))

    private func folder() async throws -> FileItem {
        let admin = try await fileSystem.addFolder("Admin", in: "documents")
        for year in ["2024", "2025"] {
            let folder = try await fileSystem.addFolder(year, in: admin.id)
            try await fileSystem.addFolder("Belastingsdienst", in: folder.id)
        }
        return try await fileSystem.item(at: "documents/Admin/2025/Belastingsdienst")
    }

    private func model(for folder: FileItem) async throws -> RenameInAllYearsModel {
        await templates.load()
        let settings = settings
        return try #require(
            await RenameInAllYearsModel.make(
                for: folder, in: fileSystem, templates: templates.templates,
                madeFrom: { await settings.settings(forFolderAt: $0.rawValue)?.madeFrom ?? [] }))
    }

    private func made(_ year: String, from id: String) async {
        var kept = FolderSettings(enabledModules: [], templates: [:])
        kept.remember(madeFrom: id)
        await settings.save(kept, forFolderAt: "documents/Admin/\(year)")
    }

    @Test func offersOnlyTheTemplatesTheYearsWereMadeFrom() async throws {
        let folder = try await folder()
        await made("2024", from: "club")
        let model = try await model(for: folder)
        #expect(model.templates.map(\.id) == ["club"])
    }

    @Test func guessesWhenNoYearKeepsATemplate() async throws {
        let model = try await model(for: try await folder())
        #expect(Set(model.templates.map(\.id)) == ["household", "club"])
    }

    @Test func eachTemplateHasItsOwnCheckbox() async throws {
        let folder = try await folder()
        await made("2024", from: "club")
        await made("2025", from: "household")
        let model = try await model(for: folder)
        model.newName = "Belastingdienst"
        model.uncorrected = ["club"]
        #expect(model.correctedTemplates.map(\.id) == ["household"])
    }

    @Test func remembersATemplateItCorrected() async throws {
        let model = try await model(for: try await folder())
        model.newName = "Belastingdienst"
        model.uncorrected = ["club"]
        let browser = await makeBrowser(fileSystem: fileSystem)
        await browser.renameInAllYears(
            model, templates: templates, settings: settings, undoManager: nil)
        for year in ["2024", "2025"] {
            let kept = await settings.settings(forFolderAt: "documents/Admin/\(year)")
            #expect(kept?.madeFrom == ["household"], "\(year) learns its template")
        }
    }
}
