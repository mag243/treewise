import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Cut, copy and paste (PLAN.md §4.3, §9.4).
@Suite struct ClipboardModelTests {
    private let notes = fixtureItem("doc2")
    private let budget = fixtureItem("doc1")

    @Test func dimsCutItems() {
        let clipboard = ClipboardModel(items: [notes], mode: .cut)
        #expect(clipboard.isCut(notes.id))
        #expect(!clipboard.isCut(budget.id))
    }

    @Test func doesNotDimCopiedItems() {
        #expect(!ClipboardModel(items: [notes], mode: .copy).isCut(notes.id))
    }

    @Test func movesWhenCutAndCopiesWhenCopied() {
        #expect(ClipboardModel(items: [notes], mode: .cut).transferMode == .move)
        #expect(ClipboardModel(items: [notes], mode: .copy).transferMode == .copy)
    }

    @Test func forgetsItemsThatWereRemoved() throws {
        let clipboard = ClipboardModel(items: [notes, budget], mode: .copy)
        let pruned = try #require(clipboard.removing([notes.id]))
        #expect(pruned.items == [budget])
        #expect(pruned.removing([budget.id]) == nil)
    }
}
