import Testing
import TreewiseCore

/// The folders items were last moved or copied into, for Move to and Copy to (ADR 0147).
@Suite struct RecentTargetsTests {
    @Test func startsEmpty() {
        #expect(RecentTargets().folders.isEmpty)
    }

    @Test func putsTheNewestTargetFirst() {
        var recent = RecentTargets()
        recent.record(target: "/a", sources: ["/x"])
        recent.record(target: "/b", sources: ["/x"])
        #expect(recent.folders == ["/b", "/a"])
    }

    @Test func keepsAFolderOnceMovingItToTheFront() {
        var recent = RecentTargets()
        recent.record(target: "/a", sources: ["/x"])
        recent.record(target: "/b", sources: ["/x"])
        recent.record(target: "/a", sources: ["/x"])
        #expect(recent.folders == ["/a", "/b"])
    }

    @Test func keepsFive() {
        var recent = RecentTargets()
        for name in ["/1", "/2", "/3", "/4", "/5", "/6"] {
            recent.record(target: FileItem.ID(name), sources: ["/x"])
        }
        #expect(recent.folders == ["/6", "/5", "/4", "/3", "/2"])
        #expect(RecentTargets.limit == 5)
    }

    @Test func leavesOutATransferIntoTheFolderTheItemsAreIn() {
        var recent = RecentTargets()
        recent.record(target: "/a", sources: ["/a"])
        #expect(recent.folders.isEmpty, "a copy beside itself is no target")
    }

    @Test func countsATransferWithSomeItemsFromElsewhere() {
        var recent = RecentTargets()
        recent.record(target: "/a", sources: ["/a", "/b"])
        #expect(recent.folders == ["/a"])
    }

    @Test func leavesOutATransferWithoutItems() {
        var recent = RecentTargets()
        recent.record(target: "/a", sources: [])
        #expect(recent.folders.isEmpty)
    }

    @Test func keepsWhatItWasMadeFromUpToFive() {
        let recent = RecentTargets(folders: ["/1", "/2", "/1", "/3", "/4", "/5", "/6"])
        #expect(recent.folders == ["/1", "/2", "/3", "/4", "/5"])
    }
}
