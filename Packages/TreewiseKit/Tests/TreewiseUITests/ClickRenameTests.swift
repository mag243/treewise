import Testing
import TreewiseUI

/// Which click on a name starts a rename after the wait, as in Finder (ADR 0039).
@Suite struct ClickRenameTests {
    /// A single plain click on the name of the item that was the only selection.
    private let renaming = ClickRename(
        wasOnlySelection: true, isOnName: true, clickCount: 1, hasModifiers: false,
        dragged: false)

    @Test func beginsAfterAClickOnTheNameOfTheOnlySelection() {
        #expect(renaming.begins)
    }

    @Test func rejectsRenameWhenTheItemWasNotSelected() {
        var click = renaming
        click.wasOnlySelection = false
        #expect(!click.begins)
    }

    @Test func rejectsRenameOutsideTheName() {
        var click = renaming
        click.isOnName = false
        #expect(!click.begins)
    }

    @Test func rejectsRenameOnADoubleClick() {
        var click = renaming
        click.clickCount = 2
        #expect(!click.begins)
    }

    @Test func rejectsRenameWithAModifierKeyHeld() {
        var click = renaming
        click.hasModifiers = true
        #expect(!click.begins)
    }

    @Test func rejectsRenameAfterADrag() {
        var click = renaming
        click.dragged = true
        #expect(!click.begins)
    }
}
