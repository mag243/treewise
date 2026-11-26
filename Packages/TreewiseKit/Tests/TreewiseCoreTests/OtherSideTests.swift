import Testing
import TreewiseCore

/// The other side of a window, where Open on Other Side, ⌥-double-click and Copy and Move
/// to Other Side go (ADR 0154).
@Suite struct OtherSideTests {
    private static func layout(split: Bool, focused: Int = 0) -> PaneLayout {
        var layout = PaneLayout(at: "documents")
        if split { layout.toggleSplit(newPaneAt: "projects") }
        layout.focusPane(at: focused)
        return layout
    }

    @Test(arguments: [
        // split, focused half, another window, use → the other side
        (true, 0, false, OtherSide.Use.opening, OtherSide.pane(1)),
        (true, 1, false, .opening, .pane(0)),
        (true, 0, true, .sending, .pane(1)),
        (true, 1, true, .sending, .pane(0)),
        (false, 0, true, .opening, .otherWindow),
        (false, 0, true, .sending, .otherWindow),
        (false, 0, false, .opening, .newWindowBeside),
    ])
    func isTheOtherHalfOfASplitWindowAndOtherwiseTheOtherWindow(
        split: Bool, focused: Int, hasOtherWindow: Bool, use: OtherSide.Use, side: OtherSide
    ) {
        let layout = Self.layout(split: split, focused: focused)
        #expect(layout.otherSide(hasOtherWindow: hasOtherWindow, for: use) == side)
    }

    @Test func nothingIsSentWithoutAnotherHalfOrWindow() {
        let layout = Self.layout(split: false)
        #expect(layout.otherSide(hasOtherWindow: false, for: .sending) == nil)
    }
}
