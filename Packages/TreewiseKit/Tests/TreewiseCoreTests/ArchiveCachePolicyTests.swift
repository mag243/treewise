import Testing

@testable import TreewiseCore

/// How much of an archive a preview extracts (ADR 0076).
@Suite struct ArchiveCachePolicyTests {
    private static let gigabyte: Int64 = 1_000_000_000

    struct Situation: Sendable {
        var name: String
        var total: Int64
        var free: Int64
        var whole: Bool
    }

    @Test(arguments: [
        Situation(name: "a.zip", total: gigabyte, free: 10 * gigabyte, whole: false),
        Situation(name: "A.ZIP", total: gigabyte, free: 10 * gigabyte, whole: false),
        Situation(name: "a.7z", total: gigabyte, free: 10 * gigabyte, whole: true),
        Situation(name: "a.tar.gz", total: gigabyte, free: 10 * gigabyte, whole: true),
        Situation(name: "a.tar.gz", total: 2 * gigabyte, free: 10 * gigabyte, whole: true),
        Situation(name: "a.tar.gz", total: 2 * gigabyte + 1, free: 10 * gigabyte, whole: false),
        Situation(name: "a.7z", total: gigabyte, free: gigabyte, whole: false),
        Situation(name: "a.7z", total: gigabyte, free: gigabyte - 1, whole: false),
    ])
    func extractsAsAWholeWhenAnEntryCannotBeReachedDirectly(situation: Situation) {
        #expect(
            ArchiveCachePolicy.extractsWhole(
                archiveName: situation.name, totalBytes: situation.total, freeBytes: situation.free)
                == situation.whole)
    }

    @Test func extractsPerEntryWhenTheFreeSpaceIsUnknown() {
        #expect(
            !ArchiveCachePolicy.extractsWhole(archiveName: "a.7z", totalBytes: 1, freeBytes: nil))
    }
}
