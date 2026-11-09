#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// The old versions of a changed archive, and undo (ADR 0078), inside a TempDirectory.
    @Suite struct ArchiveVersionTests: ArchiveTesting {
        private func change(
            _ edit: ArchiveEdit, _ runner: FileOperationRunner, _ directory: TempDirectory
        ) async throws -> UndoRecord {
            try await runner.apply(
                edit, to: id(directory, "Photos.zip"), onProgress: { _ in },
                control: TransferControl())
        }

        private func bytes(_ directory: TempDirectory) throws -> Data {
            try Data(contentsOf: directory.url("Photos.zip"))
        }

        private func trashed(_ directory: TempDirectory) throws -> [String] {
            guard manager.fileExists(atPath: directory.url("trash").path) else { return [] }
            return try names(directory, in: "trash")
        }

        @Test func theFirstChangePutsTheOriginalInTheTrash() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let original = try bytes(directory)

            _ = try await change(.newFolder("One"), runner(directory), directory)

            let inTrash = try #require(try trashed(directory).first)
            #expect(inTrash.hasSuffix("Photos.zip"))
            #expect(try Data(contentsOf: directory.url("trash/\(inTrash)")) == original)
        }

        @Test func laterChangesLeaveTheTrashAlone() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)

            _ = try await change(.newFolder("One"), runner, directory)
            _ = try await change(.newFolder("Two"), runner, directory)
            _ = try await change(.newFolder("Three"), runner, directory)

            #expect(try trashed(directory).count == 1)
        }

        @Test func aFailedChangePutsNothingInTheTrash() async throws {
            let directory = try TempDirectory()
            try writeDamaged(directory)

            await #expect(throws: FileSystemError.self) {
                try await runner(directory).apply(
                    .newFolder("One"), to: id(directory, "Broken.zip"), onProgress: { _ in },
                    control: TransferControl())
            }

            #expect(try trashed(directory).isEmpty)
        }

        @Test func undoPutsTheVersionBeforeTheChangeBack() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)
            let before = try bytes(directory)

            let undo = try await change(.newFolder("One"), runner, directory)
            #expect(try bytes(directory) != before)
            try await runner.undo(undo)

            #expect(try bytes(directory) == before)
        }

        @Test func undoGoesBackStepByStep() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)
            let original = try bytes(directory)

            let first = try await change(.newFolder("One"), runner, directory)
            let afterFirst = try bytes(directory)
            let second = try await change(.newFolder("Two"), runner, directory)

            try await runner.undo(second)
            #expect(try bytes(directory) == afterFirst)
            try await runner.undo(first)
            #expect(try bytes(directory) == original)
        }

        @Test func redoPutsTheChangeBack() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)

            let undo = try await change(.newFolder("One"), runner, directory)
            let changed = try bytes(directory)
            let redo = try await runner.undo(undo).undo
            try await runner.undo(redo)

            #expect(try bytes(directory) == changed)
        }

        @Test func undoRefusesWhenTheArchiveChangedSince() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)
            let undo = try await change(.newFolder("One"), runner, directory)
            let elsewhere = Data("someone else's zip".utf8)
            try elsewhere.write(to: directory.url("Photos.zip"))

            await #expect(throws: FileSystemError.archiveChangedSince(id(directory, "Photos.zip")))
            {
                try await runner.undo(undo)
            }

            #expect(try bytes(directory) == elsewhere)
        }

        @Test func aVolumeWithoutATrashDoesNotStopTheChange() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let locations = LocalFileSystem.Locations(
                home: directory.url("home"), applications: directory.url("Applications"),
                moveToTrash: { throw FileSystemError.trashUnavailable(FileItem.ID($0.path)) })
            let runner = FileOperationRunner(locations: locations)

            let undo = try await change(.newFolder("One"), runner, directory)

            #expect(
                try ArchiveFixtures.list(directory.url("Photos.zip")).contains {
                    $0.hasPrefix("One")
                })
            try await runner.undo(undo)
            #expect(
                !(try ArchiveFixtures.list(directory.url("Photos.zip")).contains {
                    $0.hasPrefix("One")
                }))
        }

        @Test func versionsAreHiddenFromTheList() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)
            _ = try await change(.newFolder("One"), runner, directory)

            let names = try await runner.contents(of: FileItem.ID(directory.path)).map(\.name)

            #expect(!names.contains { $0.hasPrefix(".treewise") })
        }

        @Test func versionsAreRemovedAtTheEnd() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let locations = locations(directory)
            let runner = FileOperationRunner(locations: locations)
            _ = try await change(.newFolder("One"), runner, directory)
            #expect(try names(directory, in: ".").contains { $0.hasPrefix(".treewise") })

            FileOperationRunner.removeLeftoverArchiveCopies(in: locations)

            #expect(!(try names(directory, in: ".").contains { $0.hasPrefix(".treewise") }))
            #expect(manager.fileExists(atPath: directory.url("Photos.zip").path))
        }
    }
#endif
