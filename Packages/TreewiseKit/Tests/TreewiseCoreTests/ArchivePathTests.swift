import Testing

@testable import TreewiseCore

/// The form of an identifier inside an archive (ADR 0076).
@Suite struct ArchivePathTests {
    @Test(arguments: [
        ("/Downloads/Photos.zip//", "/Downloads/Photos.zip", ""),
        ("/Downloads/Photos.zip//beach.jpg", "/Downloads/Photos.zip", "beach.jpg"),
        ("/Downloads/Photos.zip//2024/beach.jpg", "/Downloads/Photos.zip", "2024/beach.jpg"),
    ])
    func readsAnIdentifierInsideAnArchive(raw: String, archive: String, entry: String) throws {
        let path = try #require(ArchivePath(FileItem.ID(raw)))
        #expect(path.archive == FileItem.ID(archive))
        #expect(path.entry == entry)
    }

    @Test(arguments: [
        "/Downloads/Photos.zip", "/Downloads", "/", "doc2", "computer:", "//Users//x/",
        "/Users//x", "/Users/x//", "/d/a.zip//b/", "/d/a.zip//b//c",
    ])
    func readsNothingFromAnIdentifierOutsideAnArchive(raw: String) {
        #expect(ArchivePath(FileItem.ID(raw)) == nil)
        #expect(!FileItem.ID(raw).isInsideArchive)
    }

    @Test(arguments: [
        ("/Downloads/Photos.zip", "", "/Downloads/Photos.zip//"),
        ("/Downloads/Photos.zip", "2024/beach.jpg", "/Downloads/Photos.zip//2024/beach.jpg"),
    ])
    func writesTheIdentifier(archive: String, entry: String, raw: String) {
        let id = ArchivePath(archive: FileItem.ID(archive), entry: entry).id
        #expect(id == FileItem.ID(raw))
        #expect(id.isInsideArchive)
    }

    @Test func theTopLevelIsKnownByItsEmptyEntry() {
        #expect(ArchivePath(archive: "/a.zip").isTopLevel)
        #expect(!ArchivePath(archive: "/a.zip", entry: "b").isTopLevel)
    }

    @Test(arguments: [
        ("/d/a.zip//x/y/z.txt", "/d/a.zip//x/y"),
        ("/d/a.zip//x/y", "/d/a.zip//x"),
        ("/d/a.zip//x", "/d/a.zip//"),
        ("/d/a.zip//", "/d"),
        ("/a.zip//", "/"),
    ])
    func theParentLeadsOutOfTheArchiveLevelByLevel(raw: String, parent: String) throws {
        let path = try #require(ArchivePath(FileItem.ID(raw)))
        #expect(path.parent == FileItem.ID(parent))
    }

    @Test(arguments: [
        ("/d/a.zip//x/y.txt", "y.txt"),
        ("/d/a.zip//x", "x"),
        ("/d/Photos.tar.gz//", "Photos.tar.gz"),
    ])
    func theNameIsTheLastPartOrTheArchives(raw: String, name: String) throws {
        let path = try #require(ArchivePath(FileItem.ID(raw)))
        #expect(path.name == name)
    }

    @Test func eachArchiveIsAVolumeOfItsOwn() {
        let first = ArchivePath(archive: "/d/a.zip", entry: "x")
        let sameArchive = ArchivePath(archive: "/d/a.zip", entry: "y/z")
        let other = ArchivePath(archive: "/d/b.zip", entry: "x")
        #expect(first.volume == sameArchive.volume)
        #expect(first.volume != other.volume)
    }

    @Test func aChildAddsToTheEntry() {
        let top = ArchivePath(archive: "/d/a.zip")
        #expect(top.child("x") == ArchivePath(archive: "/d/a.zip", entry: "x"))
        #expect(top.child("x").child("y") == ArchivePath(archive: "/d/a.zip", entry: "x/y"))
    }

    @Test(arguments: [
        ("/d/a.zip//", "/d/a.zip"),
        ("/d/a.zip//x/y.txt", "/d/a.zip/x/y.txt"),
        ("/d/note.txt", "/d/note.txt"),
    ])
    func aPathIsShownWithASingleSlash(raw: String, shown: String) {
        #expect(FileItem.ID(raw).shownPath == shown)
    }
}
