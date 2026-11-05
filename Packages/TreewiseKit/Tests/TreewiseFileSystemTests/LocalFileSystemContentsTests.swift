import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Reading a folder (PLAN.md §9.3, ADR 0016), always inside a TempDirectory.
@Suite struct LocalFileSystemContentsTests {
    private func fileSystem(in directory: TempDirectory) -> LocalFileSystem {
        LocalFileSystem(
            locations: .init(
                home: directory.url("home"), applications: directory.url("Applications")))
    }

    @Test func listsTheItemsOfAFolder() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Projects")
        try directory.makeFile("Notes.md", contents: "x")
        let names = try await fileSystem(in: directory).contents(of: FileItem.ID(directory.path))
            .map(\.name).sorted()
        #expect(names == ["Notes.md", "Projects"])
    }

    @Test func marksDotFilesAndFlaggedFilesHidden() async throws {
        let directory = try TempDirectory()
        try directory.makeFile(".hidden")
        var flagged = try directory.makeFile("Flagged.txt")
        var values = URLResourceValues()
        values.isHidden = true
        try flagged.setResourceValues(values)
        try directory.makeFile("visible.txt")

        let items = try await fileSystem(in: directory).contents(of: FileItem.ID(directory.path))
        let hidden = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.isHidden) })
        #expect(hidden == [".hidden": true, "Flagged.txt": true, "visible.txt": false])
    }

    @Test func neverListsTreewisesOwnTemporaryItems() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder(".treewise-partial-1234")
        try directory.makeFolder(".treewise-inbox-5678")
        try directory.makeFile("visible.txt")
        let names = try await fileSystem(in: directory).contents(of: FileItem.ID(directory.path))
            .map(\.name)
        #expect(names == ["visible.txt"])
    }

    @Test func buildsChildIdentitiesFromTheFoldersIdentity() async throws {
        let directory = try TempDirectory()
        try directory.makeFile("Notes.md")
        let folder = FileItem.ID(directory.path)
        let notes = try #require(try await fileSystem(in: directory).contents(of: folder).first)
        #expect(notes.id == FileItem.ID(directory.path + "/Notes.md"))
        #expect(notes.parentID == folder)
    }

    @Test func throwsNotFoundForAMissingFolder() async throws {
        let directory = try TempDirectory()
        let missing = FileItem.ID(directory.path + "/missing")
        await #expect(throws: FileSystemError.notFound(missing)) {
            try await fileSystem(in: directory).contents(of: missing)
        }
    }

    @Test func throwsNotReadableForAFolderWithoutReadPermission() async throws {
        let directory = try TempDirectory()
        let locked = try directory.makeFolder("locked")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: locked.path)
        }
        let id = FileItem.ID(locked.path)
        await #expect(throws: FileSystemError.notReadable(id)) {
            try await fileSystem(in: directory).contents(of: id)
        }
    }

    @Test func givesEveryItemTheSystemsKindText() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Projects")
        try directory.makeFile("a.md")
        try directory.makeFile("b.md")
        try directory.makeSymlink("Shortcut", to: "Projects")
        let items = try await fileSystem(in: directory).contents(of: FileItem.ID(directory.path))
        let texts = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.kindDescription) })

        for item in items {
            let system = try item.id.rawValue.withURL {
                try $0.resourceValues(forKeys: [.localizedTypeDescriptionKey])
                    .localizedTypeDescription
            }
            #expect(texts[item.name] == system, "\(item.name)")
        }
        #expect(texts["Shortcut"] != texts["Projects"])
    }
}

extension String {
    fileprivate func withURL<Result>(_ body: (URL) throws -> Result) rethrows -> Result {
        try body(URL(fileURLWithPath: self))
    }
}
