import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Where the address bar's path starts (ADR 0069).
@MainActor
@Suite struct BrowserStateAddressTests {
    private static let iCloud: FileItem.ID =
        "/Users/m/Library/Mobile Documents/com~apple~CloudDocs"
    /// A disk, a home folder with iCloud Drive inside it, and another cloud folder.
    private static let tree = InMemoryFileSystem([
        FileItem(id: "/", name: "Macintosh HD", kind: .volume, parentID: .computer, volume: "hd"),
        FileItem(id: "/Users/m", name: "m", kind: .home, parentID: .computer, volume: "hd"),
        FileItem(id: iCloud, name: "iCloud Drive", kind: .cloud, parentID: .computer, volume: "hd"),
        FileItem(
            id: "/Users/m/Library/CloudStorage/Dropbox", name: "Dropbox", kind: .cloud,
            parentID: .computer, volume: "hd"),
        FileItem(
            id: "/Users/m/Documents", name: "Documents", kind: .folder, parentID: "/Users/m",
            volume: "hd"),
    ])

    private func names(_ folder: FileItem.ID, boundary: [MountPoint] = []) async -> [String] {
        let browser = await makeBrowser(fileSystem: Self.tree, at: "/Users/m/Documents")
        return browser.addressPath(of: folder, boundary: boundary).map(\.name)
    }

    @Test func startsAtTheHomeFolder() async {
        #expect(await names("/Users/m/Documents/Tax") == ["m", "Documents", "Tax"])
    }

    @Test func startsAtTheInnermostLocation() async {
        #expect(
            await names(FileItem.ID(Self.iCloud.rawValue + "/Notes")) == ["iCloud Drive", "Notes"])
    }

    @Test func startsAtACloudFolder() async {
        #expect(
            await names("/Users/m/Library/CloudStorage/Dropbox/Clients") == ["Dropbox", "Clients"])
    }

    @Test func startsAtThisMacElsewhereOnAVolume() async {
        #expect(await names("/Users") == ["This Mac", "Macintosh HD", "Users"])
        #expect(await names("/Library/Fonts") == ["This Mac", "Macintosh HD", "Library", "Fonts"])
    }

    @Test func thisMacIsAPathOfItsOwn() async {
        #expect(await names(.computer) == ["This Mac"])
    }

    @Test func aBoundaryFolderStartsThePath() async {
        let boundary = [MountPoint(path: "/tmp/root", name: "root")]
        #expect(await names("/tmp/root/a", boundary: boundary) == ["root", "a"])
    }
}
