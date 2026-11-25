import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// A window follows the git state of the folders its panes show, and sorts by it (ADR 0149).
@MainActor
@Suite struct BrowserStateGitTests {
    let reader = ScriptedGitReader()

    private func browser() async -> (BrowserState, GitRepository) {
        let repository = reader.addRepository(
            at: "documents",
            porcelain:
                "# branch.head main\n1 .M N... 100644 100644 100644 a b Notes.md\n? Invoices/",
            paths: ["doc2": "Notes.md", "invoices": "Invoices", "doc1": "Budget 2026.xlsx"])
        let browser = BrowserState(
            fileSystem: Fixture.standard, watcher: ManualFolderWatcher(), startFolder: "documents",
            gitStatus: GitStatusModel(reader: reader, pause: .zero))
        await browser.start()
        return (browser, repository)
    }

    private func settles(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<1_000 {
            if condition() { return true }
            await Task.yield()
        }
        return condition()
    }

    private var tab: (BrowserState) -> TabModel.ID { { $0.layout.focusedPane.activeTabID } }

    @Test func theShownFoldersItemsHaveTheirState() async throws {
        let (browser, _) = await browser()
        defer { browser.stop() }
        let notes = try #require(browser.visibleItems(of: tab(browser)).first { $0.id == "doc2" })

        #expect(await settles { browser.gitState(of: notes, in: tab(browser)) == .modified })
        #expect(browser.gitRepositoryStatus(of: tab(browser))?.head == .branch("main"))
    }

    @Test func sortsByTheGitColumn() async {
        let (browser, _) = await browser()
        defer { browser.stop() }
        #expect(await settles { browser.gitRepositoryStatus(of: tab(browser)) != nil })

        browser.sort(by: .git)

        let first = browser.visibleItems(of: tab(browser)).prefix(2).map(\.id)
        #expect(Array(first) == ["invoices", "manuals"], "folders first, the new one on top")
        #expect(
            browser.visibleItems(of: tab(browser)).first { !$0.isContainer }?.id == "doc2")
    }

    @Test func leavingTheFolderStopsFollowingIt() async {
        let (browser, repository) = await browser()
        #expect(await settles { reader.watchedRepositories == [repository] })

        await browser.navigate(pane: 0, to: "projects")

        #expect(await settles { reader.watchedRepositories.isEmpty })
        browser.stop()
    }

    @Test func aClosedWindowStopsFollowing() async {
        let (browser, repository) = await browser()
        #expect(await settles { reader.watchedRepositories == [repository] })

        browser.stop()

        #expect(await settles { reader.watchedRepositories.isEmpty })
    }

    @Test func withoutAGitModelNothingIsFollowed() async throws {
        let browser = await makeBrowser()
        defer { browser.stop() }
        let notes = try #require(browser.visibleItems(of: tab(browser)).first)
        #expect(browser.gitState(of: notes, in: tab(browser)) == nil)
        #expect(browser.gitRepositoryStatus(of: tab(browser)) == nil)
    }
}
