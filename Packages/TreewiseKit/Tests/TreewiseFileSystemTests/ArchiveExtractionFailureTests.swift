#if os(macOS)
    import Foundation
    import Synchronization
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// What extracting does with a bad archive, a stop and a hostile path (ADR 0074).
    @Suite struct ArchiveExtractionFailureTests: ArchiveTesting {
        @Test func aDamagedArchiveLeavesNothingBehind() async throws {
            let directory = try TempDirectory()
            try writeDamaged(directory)

            await #expect(throws: FileSystemError.archiveDamaged(id(directory, "Broken.zip"))) {
                try await extract(directory, "Broken.zip")
            }

            #expect(try names(directory, in: "to") == [])
        }

        @Test func anUnknownFormatIsNamedAsSuch() async throws {
            let directory = try TempDirectory()
            try directory.makeFile("Notes.zip", contents: "This is not an archive at all.")

            await #expect(throws: FileSystemError.archiveFormatUnknown(id(directory, "Notes.zip")))
            {
                try await extract(directory, "Notes.zip")
            }

            #expect(try names(directory, in: "to") == [])
        }

        @Test(arguments: ["traditional", "aes256"])
        func aPasswordIsNamedAsSuchAndExtractsNothing(_ encryption: String) async throws {
            let directory = try TempDirectory()
            try directory.makeFile("a.txt", contents: "secret")
            try ArchiveFixtures.tar([
                "--format", "zip", "--options", "zip:encryption=\(encryption)", "--passphrase",
                "secret", "-cf", directory.url("Locked.zip").path, "-C", directory.path, "a.txt",
            ])

            await #expect(
                throws: FileSystemError.archivePasswordProtected(id(directory, "Locked.zip"))
            ) {
                try await extract(directory, "Locked.zip")
            }

            #expect(try names(directory, in: "to") == [])
        }

        @Test func aFileNamedLikeAPasswordDoesNotMakeADamagedArchiveLocked() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.rawTar([(name: "../password encrypted.txt", linkTarget: nil)])
                .write(to: directory.url("Broken.tar"))

            await #expect(throws: FileSystemError.archiveDamaged(id(directory, "Broken.tar"))) {
                try await extract(directory, "Broken.tar")
            }
        }

        @Test func aTakenDestinationIsNotOverwritten() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            try directory.makeFolder("to/Out")
            try directory.makeFile("to/Out/mine.txt")

            await #expect(throws: FileSystemError.alreadyExists(id(directory, "to/Out"))) {
                try await extract(directory, "Photos.zip")
            }

            #expect(try names(directory, in: "to") == ["Out"])
            #expect(try names(directory, in: "to/Out") == ["mine.txt"])
        }

        @Test func stopLeavesNothingBehind() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let control = TransferControl()
            control.stop()

            await #expect(throws: FileSystemError.cancelled) {
                try await extract(directory, "Photos.zip", control: control)
            }

            #expect(try names(directory, in: "to") == [])
        }

        @Test func stopReachesAPausedExtraction() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            try directory.makeFolder("to")
            let runner = runner(directory)
            let archive = try await runner.item(at: id(directory, "Photos.zip"))
            let target = id(directory, "to")
            let control = TransferControl()
            control.pause()

            let extraction = Task {
                try await runner.extract(
                    archive, into: target, as: "Out", onProgress: { _ in }, control: control)
            }
            control.stop()

            await #expect(throws: FileSystemError.cancelled) { try await extraction.value }
            #expect(try names(directory, in: "to") == [])
        }

        @Test func aPausedExtractionGoesOnAfterResume() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            try directory.makeFolder("to")
            let runner = runner(directory)
            let archive = try await runner.item(at: id(directory, "Photos.zip"))
            let target = id(directory, "to")
            let control = TransferControl()
            control.pause()

            let extraction = Task {
                try await runner.extract(
                    archive, into: target, as: "Out", onProgress: { _ in }, control: control)
            }
            control.resume()

            #expect(try await extraction.value.name == "Out")
        }

        @Test func stopRemovesWhatAReadOnlyEntryProtects() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, "Disc.iso", options: ["--format", "iso9660"])
            let control = TransferControl()
            let stopped = Mutex(false)

            await #expect(throws: FileSystemError.cancelled) {
                try await extract(directory, "Disc.iso", control: control) { _ in
                    control.stop()
                    stopped.withLock { $0 = true }
                }
            }

            #expect(stopped.withLock { $0 })
            #expect(try names(directory, in: "to") == [])
        }

        @Test func aPathOutOfTheDestinationExtractsNothing() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.rawTar([
                (name: "fine.txt", linkTarget: nil), (name: "../../evil.txt", linkTarget: nil),
            ]).write(to: directory.url("Evil.tar"))

            await #expect(throws: FileSystemError.archiveDamaged(id(directory, "Evil.tar"))) {
                try await extract(directory, "Evil.tar")
            }

            #expect(try names(directory, in: "to") == [])
            #expect(!manager.fileExists(atPath: directory.url("evil.txt").path))
        }

        @Test func aLinkOutOfTheDestinationCarriesNothingThroughIt() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("outside")
            try ArchiveFixtures.rawTar([
                (name: "out", linkTarget: directory.url("outside").path),
                (name: "out/evil.txt", linkTarget: nil),
            ]).write(to: directory.url("Evil.tar"))

            await #expect(throws: FileSystemError.archiveDamaged(id(directory, "Evil.tar"))) {
                try await extract(directory, "Evil.tar")
            }

            #expect(try names(directory, in: "outside") == [])
            #expect(try names(directory, in: "to") == [])
        }

        @Test func anAbsolutePathLandsInsideTheDestination() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.rawTar([(name: "/treewise-absolute.txt", linkTarget: nil)])
                .write(to: directory.url("Absolute.tar"))

            try await extract(directory, "Absolute.tar")

            #expect(try names(directory, in: "to/Out") == ["treewise-absolute.txt"])
            #expect(!manager.fileExists(atPath: "/treewise-absolute.txt"))
        }

        @Test func keepsToTheBoundary() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let allowed = try directory.makeFolder("allowed")
            try directory.makeFolder("to")
            let runner = runner(directory, boundary: [allowed])
            let archive = FileItem(
                id: id(directory, "Photos.zip"), name: "Photos.zip", kind: .file, parentID: nil,
                volume: VolumeID("test"))

            await #expect(throws: FileSystemError.outsideBoundary(archive.id)) {
                try await runner.extract(
                    archive, into: FileItem.ID(allowed.path), as: "Out", onProgress: { _ in },
                    control: TransferControl())
            }

            #expect(try names(directory, in: "allowed") == [])
        }
    }
#endif
