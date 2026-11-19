import Testing
import TreewiseCore
import TreewiseUI

/// Which rows a click and a rectangle select with a trackpad or mouse on the iPad (ADR 0136).
@Suite struct PointerSelectionTests {
    private let items: [FileItem.ID] = ["a", "b", "c", "d"]

    @Test func aClickSelectsTheRowAlone() {
        let start = PointerSelection(selection: ["a", "b"], anchor: "a")
        let clicked = start.clicked("c", in: items)
        #expect(clicked.selection == ["c"])
        #expect(clicked.anchor == "c")
    }

    @Test func aCommandClickAddsOrRemovesTheRow() {
        let start = PointerSelection(selection: ["a"], anchor: "a")
        let added = start.clicked("c", modifiers: .command, in: items)
        #expect(added.selection == ["a", "c"])
        #expect(added.clicked("a", modifiers: .command, in: items).selection == ["c"])
    }

    @Test func aShiftClickSelectsFromTheRowClickedBefore() {
        let start = PointerSelection(selection: ["b"], anchor: "b")
        #expect(start.clicked("d", modifiers: .shift, in: items).selection == ["b", "c", "d"])
        #expect(start.clicked("a", modifiers: .shift, in: items).selection == ["a", "b"])
    }

    @Test func aShiftClickKeepsItsAnchorForTheNext() {
        let start = PointerSelection(selection: ["b"], anchor: "b")
        let first = start.clicked("d", modifiers: .shift, in: items)
        #expect(first.anchor == "b")
        #expect(first.clicked("c", modifiers: .shift, in: items).selection == ["b", "c"])
    }

    @Test func aShiftClickWithoutAnAnchorSelectsTheRowAlone() {
        #expect(PointerSelection().clicked("c", modifiers: .shift, in: items).selection == ["c"])
    }

    @Test func aClickOnEmptySpaceClearsTheSelection() {
        let start = PointerSelection(selection: ["a", "b"], anchor: "a")
        #expect(start.clicked(nil, in: items).selection.isEmpty)
        #expect(start.clicked(nil, modifiers: .command, in: items).selection == ["a", "b"])
    }

    @Test func aRectangleSelectsTheRowsItTouches() {
        let start = PointerSelection(selection: ["a"], anchor: "a")
        #expect(start.banded(["c", "d"]).selection == ["c", "d"])
    }

    @Test func aRectangleWithCommandOrShiftAddsToTheSelection() {
        let start = PointerSelection(selection: ["a"], anchor: "a")
        #expect(start.banded(["c"], modifiers: .command).selection == ["a", "c"])
        #expect(start.banded(["c"], modifiers: .shift).selection == ["a", "c"])
    }

    @Test func aRightClickOutsideTheSelectionSelectsTheRow() {
        let start = PointerSelection(selection: ["a", "b"], anchor: "a")
        #expect(start.rightClicked("c").selection == ["c"])
        #expect(start.rightClicked("b").selection == ["a", "b"])
    }
}
