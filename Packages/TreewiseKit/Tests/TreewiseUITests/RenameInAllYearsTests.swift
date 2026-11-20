import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Rename in All Years…: the folder found in every year, renamed with its template and the
/// closed missing folders in one step, and one Undo for all of it (ADR 0139).
@MainActor
@Suite struct RenameInAllYearsTests {
    private static let template = FolderTemplate(
        id: "year", name: "Admin Year",
        root: FolderTree(
            name: FolderTree.yearField,
            folders: [FolderTree(name: "Belastingsdienst"), FolderTree(name: "Bank")]))

    let fileSystem = ChangingFileSystem()
    let settings = MemoryFolderSettings()
    let templates = FolderTemplatesModel(store: MemoryFolderTemplates([template]))

    /// `Admin` with 2024 and 2025 holding `Belastingsdienst`, 2026 `Belastingdienst`, and
    /// 2027 neither; gives 2025's `Belastingsdienst`.
    private func years() async throws -> FileItem {
        let admin = try await fileSystem.addFolder("Admin", in: "documents")
        for year in ["2024", "2025"] {
            let folder = try await fileSystem.addFolder(year, in: admin.id)
            try await fileSystem.addFolder("Belastingsdienst", in: folder.id)
        }
        let year2026 = try await fileSystem.addFolder("2026", in: admin.id)
        try await fileSystem.addFolder("Belastingdienst", in: year2026.id)
        try await fileSystem.addFolder("2027", in: admin.id)
        try await fileSystem.addFolder("Notes", in: admin.id)
        return try await fileSystem.item(at: "documents/Admin/2025/Belastingsdienst")
    }

    private func model(for folder: FileItem) async throws -> RenameInAllYearsModel {
        await templates.load()
        return try #require(
            await RenameInAllYearsModel.make(
                for: folder, in: fileSystem, templates: templates.templates))
    }

    @Test func findsTheFolderInEveryYearThatHasIt() async throws {
        let model = try await model(for: try await years())
        model.newName = "Belastingdienst"
        #expect(model.places.map(model.label(of:)) == ["2024", "2025", "2026"])
        #expect(model.plan.entries.map(\.outcome) == [.renamed, .renamed, .alreadyNamed])
        #expect(model.templates.map(\.id) == ["year"])
    }

    @Test func findsAPathBelowTheYearWhateverItsCase() async throws {
        let admin = try await fileSystem.addFolder("Admin", in: "documents")
        for (year, quarter) in [("2024", "q1"), ("2025", "Q1")] {
            let folder = try await fileSystem.addFolder(year, in: admin.id)
            let inside = try await fileSystem.addFolder(quarter, in: folder.id)
            try await fileSystem.addFolder("Bank", in: inside.id)
        }
        let folder = try await fileSystem.item(at: "documents/Admin/2025/Q1/Bank")
        let model = try await model(for: folder)
        #expect(model.places.map(model.label(of:)) == ["2024 › q1", "2025 › Q1"])
    }

    @Test func startsFromTheOldNameWithNothingToRename() async throws {
        let model = try await model(for: try await years())
        #expect(model.newName == "Belastingsdienst")
        #expect(!model.canRename)
    }

    @Test func leavesOutAFolderUnchecked() async throws {
        let model = try await model(for: try await years())
        model.newName = "Belastingdienst"
        model.excluded = ["documents/Admin/2024/Belastingsdienst"]
        #expect(model.renames.map(\.item) == ["documents/Admin/2025/Belastingsdienst"])
    }

    private func names(in year: String) async throws -> [String] {
        try await fileSystem.contents(of: FileItem.ID("documents/Admin/\(year)")).map(\.name)
    }

    @Test func renamesCorrectsAndUndoesAsOneStep() async throws {
        let folder = try await years()
        var closed = FolderSettings(enabledModules: [], templates: [:])
        closed.missingFoldersClosed = [["Belastingsdienst"]]
        await settings.save(closed, forFolderAt: "documents/Admin/2027")
        let browser = await makeBrowser(fileSystem: fileSystem)
        let model = try await model(for: folder)
        model.newName = "Belastingdienst"
        let manager = UndoManager()
        manager.groupsByEvent = false
        manager.beginUndoGrouping()
        let result = await browser.renameInAllYears(
            model, templates: templates, settings: settings, undoManager: manager)
        manager.endUndoGrouping()
        guard case .renamed(count: 2) = result else {
            Issue.record("both years are renamed, not \(result)")
            return
        }
        #expect(try await names(in: "2024") == ["Belastingdienst"])
        #expect(try await names(in: "2025") == ["Belastingdienst"])
        #expect(templates.templates.first?.root.folder(at: ["Belastingdienst"]) != nil)
        let kept = await settings.settings(forFolderAt: "documents/Admin/2027")
        #expect(
            kept?.missingFoldersClosed == [["Belastingsdienst"], ["Belastingdienst"]],
            "closed under the new name too, and still under the old")

        manager.undo()
        #expect(
            await eventuallyAsync { try await names(in: "2024") == ["Belastingsdienst"] })
        #expect(try await names(in: "2025") == ["Belastingsdienst"])
        #expect(
            await eventuallyAsync {
                templates.templates.first?.root.folder(at: ["Belastingsdienst"]) != nil
            })
        #expect(
            await eventuallyAsync {
                await settings.settings(forFolderAt: "documents/Admin/2027")?
                    .missingFoldersClosed == [["Belastingsdienst"]]
            })
    }

    @Test func correctsAFolderThatDiffersInCaseOnly() async throws {
        let folder = try await years()
        let year2023 = try await fileSystem.addFolder("2023", in: "documents/Admin")
        try await fileSystem.addFolder("belastingdienst", in: year2023.id)
        let browser = await makeBrowser(fileSystem: fileSystem)
        let model = try await model(for: folder)
        model.newName = "Belastingdienst"
        await browser.renameInAllYears(
            model, templates: templates, settings: settings, undoManager: nil)
        #expect(try await names(in: "2023") == ["Belastingdienst"])
    }

    @Test func stoppingHalfwayLeavesTheTemplateAndUndoesWhatWasRenamed() async throws {
        let folder = try await years()
        let browser = await makeBrowser(fileSystem: fileSystem)
        let model = try await model(for: folder)
        model.newName = "Belastingdienst"
        // Made after the sheet looked, so 2025's rename finds the name taken.
        try await fileSystem.addFolder("Belastingdienst", in: "documents/Admin/2025")
        let manager = UndoManager()
        manager.groupsByEvent = false
        manager.beginUndoGrouping()
        let result = await browser.renameInAllYears(
            model, templates: templates, settings: settings, undoManager: manager)
        manager.endUndoGrouping()
        guard case .stopped(let failure, renamed: 1) = result else {
            Issue.record("it stops at 2025 after renaming 2024, not \(result)")
            return
        }
        #expect(failure.item == "documents/Admin/2025/Belastingsdienst")
        #expect(templates.templates.first?.root.folder(at: ["Belastingsdienst"]) != nil)
        manager.undo()
        #expect(await eventuallyAsync { try await names(in: "2024") == ["Belastingsdienst"] })
    }

    @Test func registersNoUndoWhenNothingWasRenamed() async throws {
        let folder = try await years()
        let browser = await makeBrowser(fileSystem: fileSystem)
        let model = try await model(for: folder)
        model.newName = "Belastingdienst"
        fileSystem.failChanges(with: FileSystemError.notWritable("documents/Admin/2024"))
        let manager = UndoManager()
        manager.groupsByEvent = false
        manager.beginUndoGrouping()
        let result = await browser.renameInAllYears(
            model, templates: templates, settings: settings, undoManager: manager)
        manager.endUndoGrouping()
        guard case .stopped(_, renamed: 0) = result else {
            Issue.record("it stops at the first folder, not \(result)")
            return
        }
        #expect(manager.undoActionName.isEmpty, "no Undo Rename in All Years that does nothing")
        #expect(templates.templates.first?.root.folder(at: ["Belastingsdienst"]) != nil)
    }
}

/// Lets other tasks run until `condition` holds, for a condition that has to await.
@MainActor
private func eventuallyAsync(_ condition: @MainActor () async throws -> Bool) async -> Bool {
    for _ in 0..<1_000 {
        if (try? await condition()) == true { return true }
        await Task.yield()
    }
    return (try? await condition()) == true
}
