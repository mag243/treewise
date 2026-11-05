import Testing
import TreewiseUI

/// Which windows a saved session holds (ADR 0038): only the open ones, in
/// their tab groups from front to back.
@Suite struct OpenWindowsTests {
    /// Each window alone, without tabs.
    private func alone(_ window: String) -> [String] { [window] }

    @Test func leavesOutAWindowThatClosed() {
        var windows = OpenWindows<String>()
        windows.open("first")
        windows.open("second")
        windows.close("second")
        #expect(windows.groups(frontToBack: ["second", "first"], tabs: alone) == [["first"]])
    }

    @Test func leavesOutATabThatClosed() {
        var windows = OpenWindows<String>()
        for tab in ["a", "b", "c"] { windows.open(tab) }
        windows.close("b")
        #expect(
            windows.groups(frontToBack: ["a"], tabs: { _ in ["a", "b", "c"] }) == [["a", "c"]])
    }

    @Test func listsATabGroupOnceWithItsTabsInOrder() {
        var windows = OpenWindows<String>()
        for window in ["a", "b", "c"] { windows.open(window) }
        let tabs = { (window: String) in window == "c" ? ["c"] : ["a", "b"] }
        #expect(windows.groups(frontToBack: ["b", "c", "a"], tabs: tabs) == [["a", "b"], ["c"]])
    }

    @Test func leavesOutAWindowThatNeverOpened() {
        var windows = OpenWindows<String>()
        windows.open("browser")
        #expect(
            windows.groups(frontToBack: ["settings", "browser"], tabs: alone) == [["browser"]])
    }

    @Test func leavesOutAGroupWhoseTabsAllClosed() {
        var windows = OpenWindows<String>()
        for window in ["a", "b"] { windows.open(window) }
        windows.close("a")
        windows.close("b")
        #expect(windows.groups(frontToBack: ["a"], tabs: { _ in ["a", "b"] }).isEmpty)
    }
}
