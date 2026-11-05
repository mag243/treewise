import Testing
import TreewiseUI

/// Where a double-clicked folder opens (ADR 0022).
@Suite struct OpenPlacementTests {
    @Test func opensWhereTheSettingSays() {
        #expect(
            OpenPlacement.forOpening(command: false, option: false, preferred: .samePane)
                == .samePane)
        #expect(
            OpenPlacement.forOpening(command: false, option: false, preferred: .otherPane)
                == .otherPane)
    }

    @Test func optionOpensOppositeTheSetting() {
        #expect(
            OpenPlacement.forOpening(command: false, option: true, preferred: .samePane)
                == .otherPane)
        #expect(
            OpenPlacement.forOpening(command: false, option: true, preferred: .otherPane)
                == .samePane)
    }

    @Test func commandOpensANewTab() {
        #expect(
            OpenPlacement.forOpening(command: true, option: false, preferred: .otherPane) == .newTab
        )
        #expect(
            OpenPlacement.forOpening(command: true, option: true, preferred: .samePane) == .newTab)
    }
}
