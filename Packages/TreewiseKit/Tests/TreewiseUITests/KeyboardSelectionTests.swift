import Testing
import TreewiseCore
import TreewiseUI

/// Moving the selection with the arrow keys on the iPad (ADR 0135).
@Suite struct KeyboardSelectionTests {
    private let items: [FileItem.ID] = ["a", "b", "c", "d"]

    @Test func downFromNothingSelectsTheFirstAndUpTheLast() {
        #expect(KeyboardSelection().moved(.down, in: items).selection == ["a"])
        #expect(KeyboardSelection().moved(.up, in: items).selection == ["d"])
    }

    @Test func anArrowSelectsTheNextItemAlone() {
        let start = KeyboardSelection(selection: ["b"], cursor: "b", anchor: "b")
        let down = start.moved(.down, in: items)
        #expect(down.selection == ["c"])
        #expect(down.cursor == "c")
        #expect(start.moved(.up, in: items).selection == ["a"])
    }

    @Test func anArrowStopsAtTheEnds() {
        let last = KeyboardSelection(selection: ["d"], cursor: "d", anchor: "d")
        #expect(last.moved(.down, in: items).selection == ["d"])
        let first = KeyboardSelection(selection: ["a"], cursor: "a", anchor: "a")
        #expect(first.moved(.up, in: items).selection == ["a"])
    }

    @Test func shiftExtendsFromTheAnchorAndShrinksBack() {
        let start = KeyboardSelection(selection: ["b"], cursor: "b", anchor: "b")
        let twice = start.moved(.down, in: items, extending: true)
            .moved(.down, in: items, extending: true)
        #expect(twice.selection == ["b", "c", "d"])
        #expect(twice.anchor == "b")
        #expect(twice.moved(.up, in: items, extending: true).selection == ["b", "c"])
    }

    @Test func aSelectionMadeElsewhereMovesFromItsLastItem() {
        let tapped = KeyboardSelection(selection: ["a", "c"], cursor: nil, anchor: nil)
        #expect(tapped.moved(.down, in: items).selection == ["d"])
    }

    @Test func aCursorThatLeftTheFolderStartsAgain() {
        let gone = KeyboardSelection(selection: ["x"], cursor: "x", anchor: "x")
        #expect(gone.moved(.down, in: items).selection == ["a"])
    }

    @Test func anEmptyFolderSelectsNothing() {
        #expect(KeyboardSelection().moved(.down, in: []).selection.isEmpty)
    }
}
