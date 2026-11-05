import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// The drag badge and its mode (PLAN.md §4.1, §9.4).
@Suite struct DragSessionTests {
    private func session(_ ids: [FileItem.ID]) -> DragSession {
        DragSession(items: ids.map(fixtureItem), ancestry: Fixture.standard.ancestry)
    }

    @Test func movesOntoAFolderOnTheSameVolume() throws {
        let badge = try #require(
            session(["doc2"]).badge(over: fixtureItem("projects"), modifiers: []))
        #expect(badge.mode == .move)
        #expect(badge.targetName == "Projects")
    }

    @Test func switchesModeWithTheModifiers() {
        let target = fixtureItem("projects")
        #expect(session(["doc2"]).badge(over: target, modifiers: .option)?.mode == .copy)
        #expect(session(["doc2"]).badge(over: target, modifiers: .command)?.mode == .move)
    }

    @Test func copiesOntoAnotherVolume() {
        #expect(session(["doc2"]).badge(over: fixtureItem("backups"), modifiers: [])?.mode == .copy)
    }

    @Test func showsNoBadgeOverAnInvalidTarget() {
        #expect(session(["projects"]).badge(over: fixtureItem("src"), modifiers: []) == nil)
        #expect(session(["doc2"]).badge(over: fixtureItem("doc1"), modifiers: []) == nil)
    }

    @Test func copiesPromisedFilesIntoAFolderWhateverTheModifiers() throws {
        let badge = try #require(DragSession.promisedBadge(over: fixtureItem("backups")))
        #expect(badge == DragSession.Badge(mode: .copy, targetName: "Backups"))
    }

    @Test func showsNoBadgeForPromisedFilesOverAFile() {
        #expect(DragSession.promisedBadge(over: fixtureItem("doc1")) == nil)
    }

    @Test func writesTheBadgeText() {
        let english = Locale(identifier: "en")
        #expect(
            DragSession.Badge(mode: .move, targetName: "Projects").text(locale: english)
                == "Move to ‘Projects’")
        #expect(
            DragSession.Badge(mode: .copy, targetName: "Backups").text(locale: english)
                == "Copy to ‘Backups’")
    }
}

/// A fixture item.
///
/// Precondition: `id` is in `Fixture.standard`.
func fixtureItem(_ id: FileItem.ID) -> FileItem {
    guard let item = Fixture.standard[id] else { preconditionFailure("\(id) is in the fixture") }
    return item
}
