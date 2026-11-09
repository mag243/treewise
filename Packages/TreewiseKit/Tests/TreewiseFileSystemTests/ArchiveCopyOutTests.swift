#if os(macOS)
    import Foundation
    import Synchronization
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// Copying out of an archive (ADR 0076), inside a TempDirectory.
    @Suite struct ArchiveCopyOutTests: ArchiveTesting {
        private func entry(
            _ runner: FileOperationRunner, _ directory: TempDirectory, _ archive: String,
            _ path: String
        ) async throws -> FileItem {
            try await runner.item(
                at: ArchivePath(archive: id(directory, archive), entry: path).id)
        }

        private func text(_ directory: TempDirectory, _ path: String) throws -> String {
            try String(contentsOf: directory.url(path), encoding: .utf8)
        }

        @discardableResult
        private func copyOut(
            _ directory: TempDirectory, _ archive: String, _ path: String, as name: String,
            control: TransferControl = TransferControl(),
            onFile: @escaping FileCopyProgress = { _, _ in }
        ) async throws -> FileItem {
            try directory.makeFolder("to")
            let runner = runner(directory)
            return try await runner.copy(
                try await entry(runner, directory, archive, path), into: id(directory, "to"),
                as: name, onFile: onFile, control: control)
        }

        @Test(arguments: ArchiveFixtures.writable.map(\.name))
        func copiesAFileOutOfEveryFormat(_ name: String) async throws {
            let directory = try TempDirectory()
            let options = try #require(ArchiveFixtures.writable.first { $0.name == name }).options
            try makeArchive(directory, name, options: options)

            let copy = try await copyOut(directory, name, "Photos/a.txt", as: "copied.txt")

            #expect(copy.id == id(directory, "to/copied.txt"))
            #expect(try text(directory, "to/copied.txt") == "hello")
            #expect(try self.names(directory, in: "to") == ["copied.txt"])
        }

        @Test(arguments: ArchiveFixtures.writable.map(\.name))
        func copiesAFolderOutOfEveryFormat(_ name: String) async throws {
            let directory = try TempDirectory()
            let options = try #require(ArchiveFixtures.writable.first { $0.name == name }).options
            try makeArchive(directory, name, options: options)

            try await copyOut(directory, name, "Photos", as: "Out")

            #expect(try text(directory, "to/Out/a.txt") == "hello")
            #expect(manager.fileExists(atPath: directory.url("to/Out/empty").path))
        }

        @Test func copiesOutOfAnArchiveThatStoresDotSlash() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.makeTree(in: directory)
            try ArchiveFixtures.tar([
                "-czf", directory.url("Dot.tgz").path, "-C", directory.url("src").path, ".",
            ])

            try await copyOut(directory, "Dot.tgz", "Photos/a.txt", as: "file.txt")
            try await copyOut(directory, "Dot.tgz", "Photos", as: "Folder")

            #expect(try text(directory, "to/file.txt") == "hello")
            #expect(try text(directory, "to/Folder/a.txt") == "hello")
        }

        @Test func copiesAFolderWithoutALineOfItsOwn() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.rawTar([(name: "only/deep/file.txt", linkTarget: nil)])
                .write(to: directory.url("Raw.tar"))

            try await copyOut(directory, "Raw.tar", "only/deep", as: "Out")

            #expect(try text(directory, "to/Out/file.txt") == "evil")
        }

        @Test func aNameThatLooksLikeAPatternMeansOnlyItself() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            try directory.makeFile("src/we[ir]d*.txt", contents: "right")
            try directory.makeFile("src/weird.txt", contents: "wrong")
            try ArchiveFixtures.tar([
                "--format", "zip", "-cf", directory.url("Glob.zip").path, "-C",
                directory.url("src").path, ".",
            ])

            try await copyOut(directory, "Glob.zip", "we[ir]d*.txt", as: "out.txt")

            #expect(try text(directory, "to/out.txt") == "right")
        }

        @Test func aFileAlreadyThereStops() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            try directory.makeFolder("to")
            try directory.makeFile("to/a.txt", contents: "mine")
            let runner = runner(directory)
            let item = try await entry(runner, directory, "Photos.zip", "Photos/a.txt")

            await #expect(throws: FileSystemError.alreadyExists(id(directory, "to/a.txt"))) {
                try await runner.copy(item, into: id(directory, "to"), as: "a.txt")
            }

            #expect(try text(directory, "to/a.txt") == "mine")
            #expect(try self.names(directory, in: "to") == ["a.txt"])
        }

        @Test func aProtectedEntryIsNamedAsSuchAndLeavesNothing() async throws {
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
                try await copyOut(directory, "Locked.zip", "secret.txt", as: "out.txt")
            }

            #expect(try self.names(directory, in: "to").isEmpty)
        }

        @Test func aStopLeavesNothing() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let control = TransferControl()
            control.stop()

            await #expect(throws: FileSystemError.cancelled) {
                try await copyOut(directory, "Photos.zip", "Photos", as: "Out", control: control)
            }

            #expect(try self.names(directory, in: "to").isEmpty)
        }

        @Test func aFolderOfAnIsoComesOutWritable() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, "Disc.iso", options: ["--format", "iso9660"])

            try await copyOut(directory, "Disc.iso", "Photos", as: "Out")

            #expect(manager.isWritableFile(atPath: directory.url("to/Out").path))
            #expect(manager.isWritableFile(atPath: directory.url("to/Out/a.txt").path))
        }

        @Test func countsTheBytesOfAFileAndAFolder() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)

            let file = try await entry(runner, directory, "Photos.zip", "Photos/a.txt")
            let folder = try await entry(runner, directory, "Photos.zip", "Photos")

            #expect(try await runner.byteCount(of: file) == 5)
            #expect(try await runner.byteCount(of: folder) > 5)
        }

        @Test func reportsWhatItCopiesOut() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let reported = Mutex<[(String, Int64)]>([])

            let onFile: FileCopyProgress = { name, bytes in
                reported.withLock { $0.append((name, bytes)) }
            }

            try await copyOut(
                directory, "Photos.zip", "Photos/a.txt", as: "out.txt", onFile: onFile)

            let last = try #require(reported.withLock { $0.last })
            #expect(last.0 == "a.txt")
            #expect(last.1 == 5)
        }

        @Test func aTransferCopiesOutAndUndoTrashesTheCopy() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            try directory.makeFolder("to")
            try directory.makeFile("to/a.txt", contents: "mine")
            let runner = runner(directory)
            let item = try await entry(runner, directory, "Photos.zip", "Photos/a.txt")

            let result = try await runner.transfer(
                [item], to: id(directory, "to"), mode: .copy, resolver: ScriptedResolver(.keepBoth))

            #expect(result.items.map(\.name) == ["a copy.txt"])
            #expect(try text(directory, "to/a copy.txt") == "hello")
            guard case .sequence(let steps) = result.undo, case .trash(let ids)? = steps.first
            else {
                Issue.record("undo moves the copy to the Trash")
                return
            }
            #expect(ids == [id(directory, "to/a copy.txt")])
        }
    }
#endif
