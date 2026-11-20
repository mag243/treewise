import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// A missing folder whose name nearly matches a folder this year holds: the bar asks whether
/// they are one folder instead of offering to make it (ADR 0139).
@MainActor
@Suite struct TemplateBarLookalikeTests {
    let fileSystem = ChangingFileSystem()
    let settings = MemoryFolderSettings()

    private func model(knowing words: Set<String> = []) -> TemplateBarModel {
        let fileSystem = fileSystem
        let model = TemplateBarModel(
            fileSystem: fileSystem, settings: settings, templates: MemoryFolderTemplates(),
            addOnMayWork: { true },
            yearBefore: { id in
                guard let folder = try? await fileSystem.item(at: id),
                    let tree = try? await fileSystem.folderTree(of: folder)
                else { return nil }
                return FolderTree(name: FolderTree.yearField, folders: tree.folders)
            })
        model.isSpelledCorrectly = { words.contains($0) }
        return model
    }

    /// `Admin` with a year's folder for each of `years`, holding its folders and `Bank`.
    @discardableResult
    private func admin(_ years: [(String, [String])]) async throws -> [FileItem] {
        let admin = try await fileSystem.addFolder("Admin", in: "documents")
        var made: [FileItem] = []
        for (year, folders) in years {
            let folder = try await fileSystem.addFolder(year, in: admin.id)
            for name in folders + ["Bank"] { try await fileSystem.addFolder(name, in: folder.id) }
            made.append(folder)
        }
        return made
    }

    private func lookalike(in year: FileItem, model: TemplateBarModel) async throws
        -> TemplateBarModel.Lookalike?
    {
        let offer = try #require(await model.missing(in: year))
        return await model.lookalike(for: offer)
    }

    @Test func asksAboutAMissingFolderNearlyNamedAsOneThere() async throws {
        let years = try await admin([("2025", ["Belastingsdienst"]), ("2026", ["Belastingdienst"])])
        let found = try #require(try await lookalike(in: years[1], model: model()))
        #expect(found.missingName == "Belastingsdienst")
        #expect(found.presentName == "Belastingdienst")
        #expect(found.missingYears == [2025])
        #expect(found.presentYears == [2026])
        #expect(found.missingFolder.id == "documents/Admin/2025/Belastingsdienst")
        #expect(found.presentFolder.id == "documents/Admin/2026/Belastingdienst")
    }

    @Test func asksNothingAboutAFolderUnlikeTheMissingOne() async throws {
        let years = try await admin([("2025", ["Belastingsdienst"]), ("2026", ["Auto"])])
        #expect(try await lookalike(in: years[1], model: model()) == nil)
    }

    @Test func twoWordsInAsManyYearsAreTwoFolders() async throws {
        let years = try await admin([("2025", ["Bonnen"]), ("2026", ["Bonen"])])
        #expect(
            try await lookalike(in: years[1], model: model(knowing: ["Bonnen", "Bonen"])) == nil)
    }

    @Test func aNameInMoreYearsMakesTheRareOneALookalike() async throws {
        let years = try await admin([
            ("2023", ["Huis"]), ("2024", ["Huis"]), ("2025", ["Huis"]), ("2026", ["Huur"]),
        ])
        let found = try #require(
            try await lookalike(in: years[3], model: model(knowing: ["Huis", "Huur"])))
        #expect(found.missingYears == [2023, 2024, 2025])
        #expect(found.presentFirst == false, "the name in the most years comes first")
    }

    @Test func addAnywayKeepsThePairApartInThatYear() async throws {
        let years = try await admin([("2025", ["Belastingsdienst"]), ("2026", ["Belastingdienst"])])
        let model = model()
        let found = try #require(try await lookalike(in: years[1], model: model))
        await model.addAnyway(found)
        #expect(try await lookalike(in: years[1], model: model) == nil)
        #expect(await model.missing(in: years[1]) != nil, "the folder is offered as before")
    }
}
