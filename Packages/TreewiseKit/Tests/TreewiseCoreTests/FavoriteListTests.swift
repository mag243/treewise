import Testing
import TreewiseCore

/// The rules of the Favorites the user chooses (ADR 0050).
@Suite struct FavoriteListTests {
    private let list = FavoriteList(folders: ["/a", "/b", "/c"])

    @Test func addsAtTheEnd() {
        var list = list
        list.add("/d")
        #expect(list.folders == ["/a", "/b", "/c", "/d"])
    }

    @Test func addsBeforeAFolder() {
        var list = list
        list.add("/d", before: "/b")
        #expect(list.folders == ["/a", "/d", "/b", "/c"])
    }

    @Test func addsAtTheEndWhenTheFolderToGoBeforeIsNotInTheList() {
        var list = list
        list.add("/d", before: "/z")
        #expect(list.folders == ["/a", "/b", "/c", "/d"])
    }

    @Test func addingAFolderTwiceChangesNothing() {
        var list = list
        list.add("/b", before: "/a")
        #expect(list.folders == ["/a", "/b", "/c"])
    }

    @Test func hasNoLimit() {
        var list = FavoriteList(folders: [])
        for index in 0..<500 { list.add(FileItem.ID("/\(index)")) }
        #expect(list.folders.count == 500)
    }

    @Test func removesAFolder() {
        var list = list
        list.remove("/b")
        #expect(list.folders == ["/a", "/c"])
    }

    @Test func removingAFolderNotInTheListChangesNothing() {
        var list = list
        list.remove("/z")
        #expect(list.folders == ["/a", "/b", "/c"])
    }

    @Test func movesBeforeAFolder() {
        var list = list
        list.move("/c", before: "/a")
        #expect(list.folders == ["/c", "/a", "/b"])
    }

    @Test func movesToTheEnd() {
        var list = list
        list.move("/a", before: nil)
        #expect(list.folders == ["/b", "/c", "/a"])
    }

    @Test func movingBeforeItselfChangesNothing() {
        var list = list
        list.move("/b", before: "/b")
        #expect(list.folders == ["/a", "/b", "/c"])
    }

    @Test func movingAFolderNotInTheListChangesNothing() {
        var list = list
        list.move("/z", before: "/a")
        #expect(list.folders == ["/a", "/b", "/c"])
    }

    @Test func followsARenamedFolder() {
        var list = list
        list.relocate("/b", to: "/renamed")
        #expect(list.folders == ["/a", "/renamed", "/c"])
    }

    @Test func followsAFolderInsideARenamedFolder() {
        var list = FavoriteList(folders: ["/a/b/c", "/ab"])
        list.relocate("/a", to: "/z")
        #expect(list.folders == ["/z/b/c", "/ab"])
    }
}
