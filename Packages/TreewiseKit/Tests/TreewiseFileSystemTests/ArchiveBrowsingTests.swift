#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// Reading the inside of an archive as folders (ADR 0076), inside a TempDirectory.
    @Suite struct ArchiveBrowsingTests: ArchiveTesting {
        private func place(_ directory: TempDirectory, _ archive: String, _ entry: String = "")
            -> FileItem.ID
        {
            ArchivePath(archive: id(directory, archive), entry: entry).id
        }

        private func names(_ items: [FileItem]) -> Set<String> {
            Set(items.map { $0.name.precomposedStringWithCanonicalMapping })
        }

        @Test(arguments: ArchiveFixtures.writable.map(\.name))
        func listsEveryFormatTarWrites(_ name: String) async throws {
            let directory = try TempDirectory()
            let options = try #require(ArchiveFixtures.writable.first { $0.name == name }).options
            try makeArchive(directory, name, options: options)
            let runner = runner(directory)

            let top = try await runner.contents(of: place(directory, name))
            let inside = try await runner.contents(of: place(directory, name, "Photos"))

            #expect(names(top) == ["Photos"])
            #expect(top.first?.kind == .folder)
            #expect(names(inside) == ["a.txt", "Caf\u{E9}.txt", "run.sh", "link", "empty"])
            #expect(inside.first { $0.name == "a.txt" }?.size == 5)
            #expect(inside.first { $0.name == "empty" }?.kind == .folder)
            #expect(inside.first { $0.name == "link" }?.kind == .file)
        }

        @Test(arguments: [ArchiveFixtures.rar4, ArchiveFixtures.rar5])
        func listsARar(_ base64: String) async throws {
            let directory = try TempDirectory()
            try #require(Data(base64Encoded: base64)).write(to: directory.url("Old.rar"))

            let top = try await runner(directory).contents(of: place(directory, "Old.rar"))

            #expect(names(top) == ["hello.txt"])
        }

        @Test func anEntryIsAnItemWithItsPlace() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let id = place(directory, "Photos.zip", "Photos/a.txt")

            let item = try await runner(directory).item(at: id)

            #expect(item.id == id)
            #expect(item.name == "a.txt")
            #expect(item.parentID == place(directory, "Photos.zip", "Photos"))
            #expect(item.modified != nil)
            #expect(item.isCopyable)
        }

        @Test func theTopLevelIsNamedAfterTheArchive() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)

            let item = try await runner(directory).item(at: place(directory, "Photos.zip"))

            #expect(item.name == "Photos.zip")
            #expect(item.kind == .folder)
            #expect(item.parentID == FileItem.ID(directory.path))
        }

        @Test func theAncestorsLeadOutOfTheArchive() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)
            let id = place(directory, "Photos.zip", "Photos/empty")

            let ancestors = try await runner.ancestorIDs(of: id)

            let expected = [
                place(directory, "Photos.zip", "Photos"), place(directory, "Photos.zip"),
                FileItem.ID(directory.path),
            ]
            #expect(Array(ancestors.prefix(3)) == expected)
            #expect(Array(LocalFileSystem.ancestry(id).prefix(3)) == expected)
        }

        @Test func aPathTheArchiveDoesNotHoldIsNotFound() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let missing = place(directory, "Photos.zip", "nothing")

            await #expect(throws: FileSystemError.notFound(missing)) {
                try await runner(directory).contents(of: missing)
            }
            await #expect(throws: FileSystemError.notFound(missing)) {
                try await runner(directory).item(at: missing)
            }
        }

        @Test func aFileIsNotAFolderToList() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let file = place(directory, "Photos.zip", "Photos/a.txt")

            await #expect(throws: FileSystemError.notFound(file)) {
                try await runner(directory).contents(of: file)
            }
        }

        @Test func anArchiveThatIsGoneIsNotFound() async throws {
            let directory = try TempDirectory()
            let missing = place(directory, "Gone.zip")

            await #expect(throws: FileSystemError.notFound(missing)) {
                try await runner(directory).contents(of: missing)
            }
            await #expect(throws: FileSystemError.notFound(missing)) {
                try await runner(directory).item(at: missing)
            }
        }

        @Test func aDamagedArchiveListsNothing() async throws {
            let directory = try TempDirectory()
            try writeDamaged(directory)

            await #expect(throws: FileSystemError.archiveDamaged(id(directory, "Broken.zip"))) {
                try await runner(directory).contents(of: place(directory, "Broken.zip"))
            }
        }

        @Test func aFileThatIsNoArchiveHasAnUnknownFormat() async throws {
            let directory = try TempDirectory()
            try directory.makeFile("Fake.zip", contents: "not an archive at all")

            await #expect(throws: FileSystemError.archiveFormatUnknown(id(directory, "Fake.zip"))) {
                try await runner(directory).contents(of: place(directory, "Fake.zip"))
            }
        }

        @Test func aProtectedZipShowsWhatItHolds() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            try directory.makeFile("src/secret.txt", contents: "hidden")
            try ArchiveFixtures.tar([
                "--format", "zip", "--options", "zip:encryption=traditional", "--passphrase", "pw",
                "-cf", directory.url("Locked.zip").path, "-C", directory.url("src").path,
                "secret.txt",
            ])

            let top = try await runner(directory).contents(of: place(directory, "Locked.zip"))

            #expect(names(top) == ["secret.txt"])
        }

        @Test func anArchiveOutsideTheBoundaryIsRefused() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let inner = try directory.makeFolder("inner")
            let id = place(directory, "Photos.zip")

            await #expect(throws: FileSystemError.outsideBoundary(id)) {
                try await runner(directory, boundary: [inner]).contents(of: id)
            }
        }

        @Test func anArchiveThatChangedIsReadAgain() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            try directory.makeFile("src/first.txt", contents: "1")
            try ArchiveFixtures.tar([
                "--format", "zip", "-cf", directory.url("A.zip").path, "-C",
                directory.url("src").path, "first.txt",
            ])
            let runner = runner(directory)
            let first = try await runner.contents(of: place(directory, "A.zip"))
            #expect(names(first) == ["first.txt"])

            try directory.makeFile("src/second-longer-name.txt", contents: "22")
            try ArchiveFixtures.tar([
                "--format", "zip", "-cf", directory.url("A.zip").path, "-C",
                directory.url("src").path, "second-longer-name.txt",
            ])

            #expect(
                names(try await runner.contents(of: place(directory, "A.zip")))
                    == ["second-longer-name.txt"])
        }

        @Test func aPlaceInsideAnArchiveHasNoFreeSpaceToTell() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)

            #expect(
                try await runner(directory).availableCapacity(of: place(directory, "Photos.zip"))
                    == nil)
        }

        @Test func aListingIsAskedForAtOnceAfterItWasRead() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let reader = LocalFileSystem(
                locations: .init(
                    home: directory.url("home"), applications: directory.url("Applications")))
            let id = place(directory, "Photos.zip", "Photos/a.txt")
            _ = try await reader.contents(of: place(directory, "Photos.zip"))

            #expect(try reader.currentItem(at: id).kind == .file)
            #expect(try reader.currentItem(at: place(directory, "Photos.zip")).kind == .folder)
        }

        @Test func beforeItsListingAPlaceCountsAsAFolder() throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let reader = LocalFileSystem(
                locations: .init(
                    home: directory.url("home"), applications: directory.url("Applications")))

            let item = try reader.currentItem(at: place(directory, "Photos.zip", "Photos"))

            #expect(item.kind == .folder)
        }

        @Test func aPlaceInAnArchiveThatIsGoneIsNotFoundAtOnce() throws {
            let directory = try TempDirectory()
            let reader = LocalFileSystem(
                locations: .init(
                    home: directory.url("home"), applications: directory.url("Applications")))
            let id = place(directory, "Gone.zip", "x")

            #expect(throws: FileSystemError.notFound(id)) { try reader.currentItem(at: id) }
        }

        @Test func nothingInsideAnArchiveCanBeChanged() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)
            let entry = try await runner.item(at: place(directory, "Photos.zip", "Photos/a.txt"))
            let folder = FileItem.ID(directory.path)
            let inside = place(directory, "Photos.zip", "Photos")

            await #expect(throws: FileSystemError.notWritable(entry.id)) {
                try await runner.trash(entry.id)
            }
            await #expect(throws: FileSystemError.notWritable(entry.id)) {
                try await runner.move(entry, into: folder, as: "a.txt")
            }
            await #expect(throws: FileSystemError.notWritable(inside)) {
                try await runner.createFolder(in: inside, named: "new")
            }
            let file = try await runner.item(at: id(directory, "Photos.zip"))
            await #expect(throws: FileSystemError.notWritable(inside)) {
                try await runner.copy(file, into: inside, as: "copy.zip")
            }
            await #expect(throws: FileSystemError.notWritable(inside)) {
                try await runner.move(file, into: inside, as: "moved.zip")
            }
        }
    }
#endif
