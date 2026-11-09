import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport
import TreewiseUI

/// Favorites the user chooses, on the fixture and on real folders (ADR 0050).
@MainActor
@Suite struct BrowserStateFavoritesTests {
    let fileSystem = ChangingFileSystem()

    private func browser(
        settings: BrowserSettings = BrowserSettings(store: MemorySettingsStore())
    ) async -> BrowserState {
        await makeBrowser(fileSystem: fileSystem, settings: settings)
    }

    @Test func startsWithTheBuiltInFavorites() async {
        let browser = await browser()
        #expect(browser.favorites.map(\.id).first == "apps")
        #expect(browser.settings.favoriteFolders == nil)
    }

    @Test func addsAFolder() async {
        let browser = await browser()
        await browser.addFavorite("movies")
        #expect(browser.favorites.map(\.id).last == "movies")
        #expect(browser.isFavorite("movies"))
    }

    @Test func addsAFolderBeforeAFavorite() async {
        let browser = await browser()
        await browser.addFavorite("movies", before: "apps")
        #expect(browser.favorites.map(\.id).first == "movies")
    }

    @Test func doesNotAddAFile() async {
        let browser = await browser()
        await browser.addFavorite("doc2")
        #expect(!browser.isFavorite("doc2"))
        #expect(browser.settings.favoriteFolders == nil)
    }

    @Test func doesNotAddThisMac() async {
        let browser = await browser()
        await browser.addFavorite(.computer)
        #expect(!browser.isFavorite(.computer))
    }

    @Test func removesABuiltInFavorite() async {
        let browser = await browser()
        await browser.removeFavorite("apps")
        #expect(!browser.isFavorite("apps"))
        #expect(await (try? fileSystem.item(at: "apps")) != nil)
    }

    @Test func movesAFavorite() async {
        let browser = await browser()
        await browser.moveFavorite("projects", before: "apps")
        #expect(browser.favorites.map(\.id).first == "projects")
    }

    @Test func restoresTheBuiltInFavorites() async {
        let browser = await browser()
        await browser.removeFavorite("apps")
        await browser.restoreDefaultFavorites()
        #expect(browser.favorites.map(\.id).first == "apps")
        #expect(browser.settings.favoriteFolders == nil)
    }

    @Test func aMissingFolderHasNoRowAndGetsItBack() async throws {
        let browser = await browser()
        await browser.addFavorite("movies")
        let movies = try await fileSystem.item(at: "movies")

        fileSystem.remove("movies")
        await browser.reloadFavorites()
        #expect(!browser.isFavorite("movies"))
        #expect(browser.settings.favoriteFolders?.contains("movies") == true)

        fileSystem.add(movies)
        await browser.reloadFavorites()
        #expect(browser.isFavorite("movies"))
    }

    @Test func aChangeOutlivesTheWindow() async {
        let store = MemorySettingsStore()
        await browser(settings: BrowserSettings(store: store)).addFavorite("movies")
        let later = await browser(settings: BrowserSettings(store: store))
        #expect(later.isFavorite("movies"))
    }

    @Test func anotherWindowFollowsAfterReloading() async {
        let settings = BrowserSettings(store: MemorySettingsStore())
        let first = await browser(settings: settings)
        let second = await browser(settings: settings)

        await first.addFavorite("movies")
        await second.reloadFavorites()

        #expect(second.isFavorite("movies"))
    }

    /// A browser on real folders, with `Work` in the home folder as a favorite.
    private func browserOnDisk(
        in directory: TempDirectory
    ) async throws -> (BrowserState, work: FileItem) {
        let home = try directory.makeFolder("home")
        let work = try directory.makeFolder("home/Work")
        try directory.makeFolder("home/Archive")
        let runner = FileOperationRunner(
            locations: .init(
                home: home, applications: directory.url("Applications"), mountedVolumes: { [] }))
        let browser = await makeBrowser(
            fileSystem: runner, at: FileItem.ID(home.standardizedFileURL.path))
        let id = FileItem.ID(work.standardizedFileURL.path)
        await browser.addFavorite(id)
        return (browser, try await runner.item(at: id))
    }

    @Test func aFavoriteFollowsARename() async throws {
        let directory = try TempDirectory()
        let (browser, work) = try await browserOnDisk(in: directory)

        await browser.rename(work, to: "Office", undoManager: nil)

        #expect(browser.favorites.map(\.name).contains("Office"))
        #expect(!browser.favorites.map(\.name).contains("Work"))
    }

    @Test func aFavoriteFollowsUndoingARename() async throws {
        let directory = try TempDirectory()
        let (browser, work) = try await browserOnDisk(in: directory)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        undoManager.beginUndoGrouping()
        await browser.rename(work, to: "Office", undoManager: undoManager)
        undoManager.endUndoGrouping()

        undoManager.undo()

        #expect(await eventuallyOnDisk { browser.favorites.map(\.name).contains("Work") })
    }

    @Test func aFavoriteFollowsAMoveByPaste() async throws {
        let directory = try TempDirectory()
        let (browser, work) = try await browserOnDisk(in: directory)
        let tab = browser.layout.focusedPane.activeTabID
        browser.setSelection([work.id], in: tab)
        browser.cutSelection()
        let archive = FileItem.ID(directory.url("home/Archive").standardizedFileURL.path)
        await browser.navigate(pane: 0, to: archive)

        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(browser.favorites.first { $0.name == "Work" }?.parentID == archive)
    }

    @Test func aFolderGoneFromDiskGetsItsRowBackWhenItReturns() async throws {
        let directory = try TempDirectory()
        let (browser, work) = try await browserOnDisk(in: directory)
        #expect(browser.isFavorite(work.id))

        try FileManager.default.removeItem(at: directory.url("home/Work"))
        await browser.reloadFavorites()
        #expect(!browser.isFavorite(work.id))

        try directory.makeFolder("home/Work")
        await browser.reloadFavorites()
        #expect(browser.isFavorite(work.id))
    }
}
