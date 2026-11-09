#if os(macOS)
    import Foundation
    import Synchronization
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// Compressing to zip, 7z and `.tar.gz` (ADR 0074), inside a TempDirectory.
    @Suite struct ArchiveCompressionTests: ArchiveTesting {
        /// Compresses items of `src` into the folder `to` as `name`.
        @discardableResult
        private func compress(
            _ directory: TempDirectory, _ items: [String] = ["Photos"], as name: String = "New.zip",
            format: ArchiveFormat = .zip, control: TransferControl = TransferControl(),
            onProgress: @escaping ArchiveProgressHandler = { _ in }
        ) async throws -> FileItem {
            try directory.makeFolder("to")
            let runner = runner(directory)
            var selection: [FileItem] = []
            for item in items {
                selection.append(try await runner.item(at: id(directory, "src/\(item)")))
            }
            return try await runner.compress(
                selection, to: NewArchive(folder: id(directory, "to"), name: name, format: format),
                onProgress: onProgress, control: control)
        }

        private func extractWithTar(_ directory: TempDirectory, _ archive: String) throws {
            let output = try directory.makeFolder("check")
            try ArchiveFixtures.tar(["-xf", directory.url(archive).path, "-C", output.path])
        }

        @Test(arguments: ArchiveFormat.allCases)
        func anArchiveHoldsTheWholeTree(_ format: ArchiveFormat) async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.makeTree(in: directory)

            let result = try await compress(directory, as: "New", format: format)

            #expect(result.id == id(directory, "to/New"))
            try extractWithTar(directory, "to/New")
            let folder = directory.url("check/Photos")
            #expect(
                try String(contentsOf: folder.appendingPathComponent("a.txt"), encoding: .utf8)
                    == "hello")
            #expect(manager.fileExists(atPath: folder.appendingPathComponent("empty").path))
            #expect(manager.isExecutableFile(atPath: folder.appendingPathComponent("run.sh").path))
            #expect(
                try manager.destinationOfSymbolicLink(
                    atPath: folder.appendingPathComponent("link").path) == "a.txt")
            #expect(
                try manager.contentsOfDirectory(atPath: folder.path)
                    .contains { $0.precomposedStringWithCanonicalMapping == "Caf\u{E9}.txt" })
        }

        @Test(arguments: [ArchiveFormat.zip, .sevenZip])
        func anArchiveForOtherSystemsHasNoMacLeftovers(_ format: ArchiveFormat) async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.makeTree(in: directory)
            try directory.makeFolder("src/Photos/deeper/__MACOSX")
            for junk in [".DS_Store", "deeper/.DS_Store", "._a.txt", "deeper/._b.txt"] {
                try directory.makeFile("src/Photos/\(junk)")
            }
            try ExtendedAttribute.write("tag", to: directory.url("src/Photos/a.txt"))

            try await compress(directory, as: "New", format: format)

            let listed = try ArchiveFixtures.list(directory.url("to/New"))
            #expect(!listed.isEmpty)
            #expect(
                listed.allSatisfy { entry in
                    !entry.contains("__MACOSX") && !entry.contains(".DS_Store")
                        && !entry.contains("/._")
                })
            try extractWithTar(directory, "to/New")
            #expect(ExtendedAttribute.read(directory.url("check/Photos/a.txt")) == nil)
        }

        @Test(arguments: ["-dash.txt", "@at.txt", "*.txt", "with space.txt"])
        func aNameMeansNothingToTar(_ name: String) async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            try directory.makeFile("src/\(name)", contents: "kept")
            try directory.makeFile("src/other.txt")

            try await compress(directory, [name])

            #expect(try ArchiveFixtures.list(directory.url("to/New.zip")) == [name])
        }

        @Test func holdsEverySelectedItemAtItsTop() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            for name in ["a.txt", "b.txt", "left out.txt"] { try directory.makeFile("src/\(name)") }

            try await compress(directory, ["a.txt", "b.txt"])

            #expect(
                try ArchiveFixtures.list(directory.url("to/New.zip")).sorted() == [
                    "a.txt", "b.txt",
                ])
        }

        @Test func reportsEachEntryOfTheTotal() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.makeTree(in: directory)
            let seen = Mutex<[ArchiveProgress]>([])

            try await compress(directory) { progress in seen.withLock { $0.append(progress) } }

            let progress = seen.withLock { $0 }
            let entries = 6
            #expect(progress.map(\.completedEntries) == Array(1...entries))
            #expect(progress.allSatisfy { $0.totalEntries == entries })
            #expect(progress.contains { $0.currentName == "Photos/a.txt" })
        }

        @Test func aTakenNameIsNotOverwritten() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.makeTree(in: directory)
            try directory.makeFolder("to")
            try directory.makeFile("to/New.zip", contents: "mine")

            await #expect(throws: FileSystemError.alreadyExists(id(directory, "to/New.zip"))) {
                try await compress(directory)
            }

            #expect(try names(directory, in: "to") == ["New.zip"])
            #expect(try String(contentsOf: directory.url("to/New.zip"), encoding: .utf8) == "mine")
        }

        @Test func stopLeavesNothingBehind() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.makeTree(in: directory)
            let control = TransferControl()

            await #expect(throws: FileSystemError.cancelled) {
                try await compress(directory, control: control) { _ in control.stop() }
            }

            #expect(try names(directory, in: "to") == [])
        }

        @Test func anItemThatVanishedLeavesNothingBehind() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.makeTree(in: directory)
            try directory.makeFolder("to")
            let runner = runner(directory)
            let vanished = try await runner.item(at: id(directory, "src/Photos"))
            try manager.removeItem(at: directory.url("src/Photos"))

            await #expect(throws: FileSystemError.self) {
                try await runner.compress(
                    [vanished],
                    to: NewArchive(folder: id(directory, "to"), name: "New.zip", format: .zip),
                    onProgress: { _ in }, control: TransferControl())
            }

            #expect(try names(directory, in: "to") == [])
        }

        @Test func keepsToTheBoundary() async throws {
            let directory = try TempDirectory()
            try ArchiveFixtures.makeTree(in: directory)
            let allowed = try directory.makeFolder("allowed")
            let runner = runner(directory, boundary: [allowed])
            let photos = FileItem(
                id: id(directory, "src/Photos"), name: "Photos", kind: .folder,
                volume: VolumeID("test"))

            await #expect(throws: FileSystemError.outsideBoundary(photos.id)) {
                try await runner.compress(
                    [photos],
                    to: NewArchive(
                        folder: FileItem.ID(allowed.path), name: "New.zip", format: .zip),
                    onProgress: { _ in }, control: TransferControl())
            }

            #expect(try names(directory, in: "allowed") == [])
        }
    }
#endif
