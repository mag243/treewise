import Foundation
import Testing

@testable import TreewiseCore

/// The folders and files an archive's listing comes to (ADR 0076).
@Suite struct ArchiveTreeTests {
    private func file(_ name: String, size: Int64 = 1, modified: Date? = nil) -> ArchiveEntry {
        ArchiveEntry(storedName: name, isFolder: false, size: size, modified: modified)
    }

    private func folder(_ name: String, modified: Date? = nil) -> ArchiveEntry {
        ArchiveEntry(storedName: name, isFolder: true, size: 0, modified: modified)
    }

    private func names(_ tree: ArchiveTree, in folder: String = "") -> Set<String> {
        Set((tree.contents(of: folder) ?? []).map(\.name))
    }

    @Test func listsTheTopLevelAndAFolder() {
        let tree = ArchiveTree(entries: [file("a.txt"), folder("d/"), file("d/b.txt")])
        #expect(names(tree) == ["a.txt", "d"])
        #expect(names(tree, in: "d") == ["b.txt"])
    }

    @Test func aFolderWithoutItsOwnLineIsAdded() throws {
        let tree = ArchiveTree(entries: [file("only/deep/file.txt")])
        #expect(names(tree) == ["only"])
        #expect(names(tree, in: "only") == ["deep"])
        #expect(names(tree, in: "only/deep") == ["file.txt"])
        #expect(try #require(tree.node(at: "only")).isFolder)
    }

    @Test(arguments: ["./a.txt", "/a.txt", "//a.txt", "././a.txt"])
    func leadingPartsOfANameGo(stored: String) {
        #expect(names(ArchiveTree(entries: [file(stored)])) == ["a.txt"])
    }

    @Test(arguments: ["./", ".", "/"])
    func theArchivesOwnRootIsNoEntry(stored: String) {
        #expect(names(ArchiveTree(entries: [folder(stored)])).isEmpty)
    }

    @Test(arguments: ["../escape.txt", "a/../../escape.txt", "a/.."])
    func anEntryTarWouldRefuseIsLeftOut(stored: String) {
        #expect(names(ArchiveTree(entries: [file(stored)])).isEmpty)
    }

    @Test(arguments: ["__MACOSX/a.txt", "__MACOSX/._a.txt", "d/__MACOSX/a.txt", "._a.txt", "d/._a"])
    func macMetadataIsLeftOut(stored: String) {
        #expect(names(ArchiveTree(entries: [file(stored)])).isEmpty)
    }

    @Test func ofTheSamePathTheLastEntryCounts() throws {
        let tree = ArchiveTree(entries: [file("a.txt", size: 1), file("./a.txt", size: 9)])
        #expect(tree.contents(of: "")?.count == 1)
        #expect(try #require(tree.node(at: "a.txt")).entry?.size == 9)
    }

    @Test func namesThatDifferOnlyInCaseBothShow() {
        let tree = ArchiveTree(entries: [file("Same.txt"), file("same.txt")])
        #expect(names(tree) == ["Same.txt", "same.txt"])
    }

    @Test func aFolderLineGivesAnAddedFolderItsDate() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let tree = ArchiveTree(entries: [file("d/a.txt"), folder("d/", modified: date)])
        #expect(try #require(tree.node(at: "d")).entry?.modified == date)
    }

    @Test func aPathWithChildrenIsAFolderWhateverItsLineSays() throws {
        let tree = ArchiveTree(entries: [file("d"), file("d/a.txt")])
        #expect(try #require(tree.node(at: "d")).isFolder)
        #expect(names(tree, in: "d") == ["a.txt"])
    }

    @Test func aPathThatIsNoFolderHasNoContents() {
        let tree = ArchiveTree(entries: [file("a.txt")])
        #expect(tree.contents(of: "a.txt") == nil)
        #expect(tree.contents(of: "missing") == nil)
        #expect(tree.node(at: "missing") == nil)
    }

    @Test(arguments: ["./d/a.txt", "/d/a.txt", "d/a.txt"])
    func findsANodeByItsStoredName(stored: String) throws {
        let tree = ArchiveTree(entries: [file("./d/a.txt", size: 4)])
        #expect(try #require(tree.node(forStoredName: stored)).entry?.size == 4)
    }

    @Test func aFileAndAFolderCountTheirBytes() {
        let tree = ArchiveTree(entries: [
            file("a.txt", size: 5), file("d/b", size: 2), file("d/e/c", size: 3),
        ])
        #expect(tree.byteCount(at: "a.txt") == 5)
        #expect(tree.byteCount(at: "d") == 5)
        #expect(tree.byteCount(at: "") == 10)
    }

    @Test func makesItemsForAPlace() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let tree = ArchiveTree(entries: [
            file("d/b.txt", size: 7, modified: date), file("d/.hidden"), folder("d/e/"),
        ])
        let folder = ArchivePath(archive: "/x/a.zip", entry: "d")
        let items = try #require(tree.items(in: folder))
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })

        let item = try #require(byName["b.txt"])
        #expect(item.id == "/x/a.zip//d/b.txt")
        #expect(item.kind == .file)
        #expect(item.parentID == "/x/a.zip//d")
        #expect(item.volume == folder.volume)
        #expect(item.size == 7)
        #expect(item.modified == date)
        #expect(try #require(byName[".hidden"]).isHidden)
        let subfolder = try #require(byName["e"])
        #expect(subfolder.kind == .folder)
        #expect(subfolder.size == nil)
    }

    @Test func theTopLevelIsAFolderNamedAfterTheArchive() throws {
        let top = ArchivePath(archive: "/x/a.zip")
        let item = try #require(ArchiveTree(entries: []).item(at: top))
        #expect(item.id == "/x/a.zip//")
        #expect(item.name == "a.zip")
        #expect(item.kind == .folder)
        #expect(item.parentID == "/x")
        #expect(item.volume == top.volume)
    }
}
