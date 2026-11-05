import Testing
import TreewiseUI

/// The row selected for a folder that is both a favorite and open in the tree.
@Suite struct SidebarSelectionTests {
    private let favorite = SidebarSelection.Candidate(row: 2, isFavorite: true)
    private let inTree = SidebarSelection.Candidate(row: 9, isFavorite: false)

    @Test func keepsAClickedTreeRowWhenTheFolderIsAlsoAFavorite() {
        #expect(SidebarSelection.row(among: [favorite, inTree], selected: 9) == 9)
    }

    @Test func keepsAClickedFavoriteWhenTheFolderIsAlsoInTheTree() {
        #expect(SidebarSelection.row(among: [favorite, inTree], selected: 2) == 2)
    }

    @Test func prefersTheTreeWhenTheSelectedRowIsAnotherFolder() {
        #expect(SidebarSelection.row(among: [favorite, inTree], selected: 5) == 9)
    }

    @Test func prefersTheTreeWhenNothingIsSelected() {
        #expect(SidebarSelection.row(among: [favorite, inTree], selected: nil) == 9)
    }

    @Test func fallsBackToTheFavoriteWhenTheTreeDoesNotShowTheFolder() {
        #expect(SidebarSelection.row(among: [favorite], selected: nil) == 2)
    }

    @Test func selectsNothingWhenNoRowStandsForTheFolder() {
        #expect(SidebarSelection.row(among: [], selected: 5) == nil)
    }
}
