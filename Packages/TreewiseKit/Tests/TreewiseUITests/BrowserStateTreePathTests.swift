import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// The way through the sidebar's tree to what a tab shows.
@MainActor
@Suite struct BrowserStateTreePathTests {
    let fileSystem = ChangingFileSystem()

    @Test func theWayEndsAtTheFolderShownAndStartsFarthestOut() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")
        let parent = try #require(try await fileSystem.item(at: "documents").parentID)

        let path = try #require(browser.treePath)

        #expect(path.last == "documents")
        #expect(path.dropLast().last == parent)
    }

    @Test func thisMacIsNotOnTheWay() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")

        #expect(browser.treePath?.contains(.computer) == false)
    }

    @Test func aFolderThatCannotBeReadHasNoWay() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")

        await browser.navigate(pane: 0, to: "missing")

        #expect(browser.treePath == nil)
    }

    @Test func theWayFollowsTheFolderShown() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem, at: "documents")

        await browser.navigate(pane: 0, to: "projects")

        #expect(browser.treePath?.last == "projects")
    }
}
