import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface
import TreewiseTestSupport

/// A request holds what a module may know of a chosen item, and no more (ADR 0057).
@Suite struct NameRequestBuilderTests {
    private let folder: TempDirectory
    private let builder = NameRequestBuilder()

    init() throws {
        folder = try TempDirectory()
    }

    private func item(
        _ name: String, kind: ItemKind = .file, isHidden: Bool = false, isOnlyOnline: Bool = false
    ) -> FileItem {
        var item = FileItem(
            id: FileItem.ID(folder.url(name).path), name: name, kind: kind,
            parentID: FileItem.ID(folder.path), volume: VolumeID("test"),
            modified: Date(timeIntervalSince1970: 100), size: 5, isHidden: isHidden)
        item.isOnlyOnline = isOnlyOnline
        return item
    }

    private func textFile(_ name: String = "notes.txt") throws -> FileItem {
        try Data("Hello".utf8).write(to: folder.url(name))
        return item(name)
    }

    @Test func describesTheItem() throws {
        let request = builder.request(
            for: try textFile(), siblings: [], neededContent: [], id: "r1")
        #expect(request.id == "r1")
        #expect(request.name == "notes.txt")
        #expect(request.contentType == "public.plain-text")
        #expect(request.byteCount == 5)
        #expect(request.modified == Date(timeIntervalSince1970: 100))
        #expect(request.created != nil)
    }

    @Test func holdsNoPath() throws {
        let request = builder.request(
            for: try textFile(), siblings: [item("other.txt")], neededContent: [.text], id: "r1")
        let encoded = String(bytes: try JSONEncoder().encode(request), encoding: .utf8)
        #expect(encoded?.contains(folder.url.lastPathComponent) == false)
    }

    @Test func givesADifferentIDEachTime() throws {
        let file = try textFile()
        let first = builder.request(for: file, siblings: [], neededContent: [])
        let second = builder.request(for: file, siblings: [], neededContent: [])
        #expect(first.id != second.id)
    }

    @Test func listsVisibleSiblingsWithoutTheItemItself() throws {
        let file = try textFile()
        let request = builder.request(
            for: file, siblings: [file, item("b.txt"), item(".hidden", isHidden: true)],
            neededContent: [])
        #expect(request.siblingNames == ["b.txt"])
    }

    @Test func limitsTheSiblings() throws {
        let siblings = (0...NameRequestBuilder.maximumSiblings).map { item("\($0).txt") }
        let request = builder.request(for: try textFile(), siblings: siblings, neededContent: [])
        #expect(request.siblingNames.count == NameRequestBuilder.maximumSiblings)
    }

    @Test func includesTheDeclaredContent() throws {
        let request = builder.request(for: try textFile(), siblings: [], neededContent: [.text])
        #expect(request.content.text == "Hello")
    }

    @Test func doesNotDownloadAFileThatIsOnlyOnline() throws {
        try Data("Hello".utf8).write(to: folder.url("cloud.txt"))
        let request = builder.request(
            for: item("cloud.txt", isOnlyOnline: true), siblings: [], neededContent: [.text])
        #expect(request.content == ModuleContent())
    }

    @Test func readsNoContentFromAFolder() throws {
        try FileManager.default.createDirectory(
            at: folder.url("sub"), withIntermediateDirectories: false)
        let request = builder.request(
            for: item("sub", kind: .folder), siblings: [], neededContent: [.text])
        #expect(request.content == ModuleContent())
    }
}
