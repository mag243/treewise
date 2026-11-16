import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Why a drop that lands is refused, as the iPad's table says it (ADR 0047, amended
/// 2026-11-16).
@Suite struct DragSessionRefusalTests {
    private static let english = Locale(identifier: "en")

    private func reason(_ ids: [FileItem.ID], onto target: FileItem.ID) -> String? {
        DragSession(items: ids.map(fixtureItem), ancestry: Fixture.standard.ancestry)
            .landingRefusalText(over: fixtureItem(target), modifiers: [], locale: Self.english)
    }

    @Test func aFolderDroppedOnItselfSaysItCannotGoIntoItself() {
        #expect(reason(["projects"], onto: "src") == "A folder can’t go into itself.")
    }

    @Test func aFileDroppedInItsOwnFolderSaysItIsAlreadyThere() {
        #expect(reason(["doc2"], onto: "documents") == "Already in ‘Documents’.")
    }

    @Test func aDropOnAFileSaysOnlyAFolderTakesItems() {
        #expect(reason(["doc2"], onto: "doc1") == "Items can only be dropped on a folder.")
    }

    @Test func anAllowedDropHasNoReason() {
        #expect(reason(["doc2"], onto: "projects") == nil)
    }
}
