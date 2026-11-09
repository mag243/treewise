import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// Which items have a file on disk (ADR 0076).
@Suite struct DiskLocationTests {
    @Test func anItemOnDiskHasItsPath() {
        let id: FileItem.ID = "/Downloads/Photos.zip"
        #expect(id.diskPath == "/Downloads/Photos.zip")
        #expect(id.diskURL?.path == "/Downloads/Photos.zip")
    }

    @Test(arguments: ["/Downloads/Photos.zip//", "/Downloads/Photos.zip//2024/beach.jpg"])
    func aPlaceInsideAnArchiveHasNone(raw: String) {
        let id = FileItem.ID(raw)
        #expect(id.diskPath == nil)
        #expect(id.diskURL == nil)
    }

    @Test(arguments: [
        ("/Downloads/Notes.md", "/Downloads/Notes.md"),
        ("/Downloads/Photos.zip//", "/Downloads/Photos.zip"),
        ("/Downloads/Photos.zip//2024/beach.jpg", "/Downloads/Photos.zip"),
    ])
    func finderShowsTheItemOrTheArchiveThatHoldsIt(raw: String, shown: String) {
        #expect(FileItem.ID(raw).urlShownInFinder.path == shown)
    }
}
