import Foundation
import Testing
import TreewiseCore

/// Which folder settings Treewise drops on its own (ADR 0072).
@Suite struct FolderSettingsCleanupTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func verdict(
        isThere: Bool, diskAttached: Bool = true, daysUnseen: Double
    ) -> FolderSettingsCleanup.Verdict {
        FolderSettingsCleanup.verdict(
            isThere: isThere, diskIsAttached: diskAttached,
            lastSeen: now.addingTimeInterval(-daysUnseen * day), now: now)
    }

    @Test func aFolderAtItsPathIsSeen() {
        #expect(verdict(isThere: true, daysUnseen: 100) == .seen)
    }

    @Test func dropsAFolderUnseenForMoreThanThirtyDaysOnAnAttachedDisk() {
        #expect(verdict(isThere: false, daysUnseen: 31) == .drop)
    }

    @Test func keepsAFolderUnseenForThirtyDaysOrLess() {
        #expect(verdict(isThere: false, daysUnseen: 30) == .keep)
        #expect(verdict(isThere: false, daysUnseen: 1) == .keep)
    }

    @Test func keepsAFolderOnADiskThatIsNotAttached() {
        #expect(verdict(isThere: false, diskAttached: false, daysUnseen: 400) == .keep)
    }

    @Test(arguments: [
        ("/Volumes/Photos/2026/Holiday", "/Volumes/Photos"),
        ("/Volumes/Photos", "/Volumes/Photos"),
        ("/Users/someone/Documents/Taxes", "/"),
        ("/Volumes", "/"),
        ("/", "/"),
    ])
    func theDiskOfAPathIsTheVolumeItIsMountedUnder(path: String, disk: String) {
        #expect(FolderSettingsCleanup.disk(of: path) == disk)
    }
}
