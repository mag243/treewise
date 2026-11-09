#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// Copies for Quick Look and opening a file (ADR 0076), inside a TempDirectory.
    @Suite struct ArchiveCacheTests: ArchiveTesting {
        private func entry(
            _ runner: FileOperationRunner, _ directory: TempDirectory, _ archive: String,
            _ path: String
        ) async throws -> FileItem {
            try await runner.item(
                at: ArchivePath(archive: id(directory, archive), entry: path).id)
        }

        private func cachedCopy(
            _ runner: FileOperationRunner, _ directory: TempDirectory, _ archive: String,
            _ path: String
        ) async throws -> URL {
            try await runner.cachedCopy(of: try await entry(runner, directory, archive, path))
        }

        @Test(arguments: ArchiveFixtures.writable.map(\.name))
        func makesACopyFromEveryFormat(_ name: String) async throws {
            let directory = try TempDirectory()
            let options = try #require(ArchiveFixtures.writable.first { $0.name == name }).options
            try makeArchive(directory, name, options: options)

            let copy = try await cachedCopy(runner(directory), directory, name, "Photos/a.txt")

            #expect(try String(contentsOf: copy, encoding: .utf8) == "hello")
            #expect(copy.lastPathComponent == "a.txt")
        }

        @Test func aCopyStaysInsideTheCacheFolder() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)

            let copy = try await cachedCopy(
                runner(directory), directory, "Photos.zip", "Photos/a.txt")

            #expect(copy.path.hasPrefix(directory.url("home/Library/Caches").path))
        }

        @Test func aZipExtractsOnlyTheEntryAsked() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)

            let copy = try await cachedCopy(
                runner(directory), directory, "Photos.zip", "Photos/a.txt")

            let sibling = copy.deletingLastPathComponent().appendingPathComponent("run.sh")
            #expect(!manager.fileExists(atPath: sibling.path))
        }

        @Test func anotherFormatExtractsAsAWhole() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, "Photos.tgz", options: ["-z"])

            let copy = try await cachedCopy(
                runner(directory), directory, "Photos.tgz", "Photos/a.txt")

            let sibling = copy.deletingLastPathComponent().appendingPathComponent("run.sh")
            #expect(manager.fileExists(atPath: sibling.path))
        }

        @Test func asksOnceForTheSameEntry() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)

            let first = try await cachedCopy(runner, directory, "Photos.zip", "Photos/a.txt")
            let second = try await cachedCopy(runner, directory, "Photos.zip", "Photos/a.txt")

            #expect(first == second)
        }

        @Test func aFolderHasACopyToo() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)

            let copy = try await cachedCopy(runner(directory), directory, "Photos.zip", "Photos")

            #expect(manager.fileExists(atPath: copy.appendingPathComponent("a.txt").path))
        }

        @Test func anArchiveThatChangedGivesAFreshCopy() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            try directory.makeFile("src/a.txt", contents: "old")
            try ArchiveFixtures.tar([
                "--format", "zip", "-cf", directory.url("A.zip").path, "-C",
                directory.url("src").path, "a.txt",
            ])
            let runner = runner(directory)
            let first = try await cachedCopy(runner, directory, "A.zip", "a.txt")
            #expect(try String(contentsOf: first, encoding: .utf8) == "old")

            try directory.makeFile("src/a.txt", contents: "new and longer")
            try ArchiveFixtures.tar([
                "--format", "zip", "-cf", directory.url("A.zip").path, "-C",
                directory.url("src").path, "a.txt",
            ])

            let second = try await cachedCopy(runner, directory, "A.zip", "a.txt")
            #expect(try String(contentsOf: second, encoding: .utf8) == "new and longer")
            #expect(!manager.fileExists(atPath: first.path))
        }

        @Test func releasingTheArchiveRemovesItsCopies() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, "Disc.iso", options: ["--format", "iso9660"])
            let runner = runner(directory)
            let copy = try await cachedCopy(runner, directory, "Disc.iso", "Photos/a.txt")

            await runner.releaseCache(of: id(directory, "Disc.iso"))

            #expect(!manager.fileExists(atPath: copy.path))
        }

        @Test func aProtectedEntryIsNamedAsSuch() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            try directory.makeFile("src/secret.txt", contents: "hidden")
            try ArchiveFixtures.tar([
                "--format", "zip", "--options", "zip:encryption=traditional", "--passphrase", "pw",
                "-cf", directory.url("Locked.zip").path, "-C", directory.url("src").path,
                "secret.txt",
            ])

            await #expect(
                throws: FileSystemError.archivePasswordProtected(id(directory, "Locked.zip"))
            ) {
                try await cachedCopy(runner(directory), directory, "Locked.zip", "secret.txt")
            }
        }

        @Test func whatAnEarlierRunLeftIsRemoved() throws {
            let directory = try TempDirectory()
            let locations = LocalFileSystem.Locations(
                home: directory.url("home"), applications: directory.url("Applications"))
            let old = locations.archiveCacheFolder.appendingPathComponent("old/file")
            try manager.createDirectory(
                at: old.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: old)

            FileOperationRunner.removeLeftoverArchiveCopies(in: locations)

            #expect(!manager.fileExists(atPath: old.path))
        }
    }
#endif
