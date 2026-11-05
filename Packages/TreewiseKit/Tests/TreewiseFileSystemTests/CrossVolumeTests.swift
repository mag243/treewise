import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

// Disk images need hdiutil, which only the Mac has.
#if os(macOS)

    extension Tag {
        /// Tests that need a disk image (`hdiutil`) as a second volume.
        @Tag static var crossVolume: Tag
    }

    /// Moving between volumes = copy, verify, remove the source (PLAN.md §9.3,
    /// ADR 0018), on a 50 MB disk image mounted inside a TempDirectory. Runs only
    /// with TREEWISE_CROSS_VOLUME=1 (`tools/build.sh crossvolume`).
    @Suite(
        .tags(.crossVolume),
        .enabled(
            if: ProcessInfo.processInfo.environment["TREEWISE_CROSS_VOLUME"] == "1",
            "set TREEWISE_CROSS_VOLUME=1 (tools/build.sh crossvolume)"))
    struct CrossVolumeTests {
        /// The size of the disk image, and of a file too large for it.
        private static let imageMegabytes = 50
        private static let tooLargeBytes = 60_000_000
        /// A file large enough for `copyfile` to report several times inside it.
        private static let largeBytes = 20_000_000
        /// How long an ejected volume may take to end a watch on it, and the
        /// mount table to report a change.
        private static let watchDeadline = Duration.seconds(5)

        /// Runs `body` with a fresh disk image mounted at `<directory>/Volume`, and
        /// detaches it afterwards, also when `body` fails.
        private func withVolume(
            in directory: TempDirectory, _ body: (URL) async throws -> Void
        ) async throws {
            let image = directory.url("Volume.dmg").path
            let mountPoint = directory.url("Volume")
            try Self.hdiutil(
                "create", "-size", "\(Self.imageMegabytes)m", "-fs", "APFS", "-volname",
                "TreewiseTest",
                image)
            try Self.hdiutil("attach", image, "-nobrowse", "-mountpoint", mountPoint.path)
            defer { try? Self.hdiutil("detach", mountPoint.path, "-force") }
            try await body(mountPoint)
        }

        private static func hdiutil(_ arguments: String...) throws {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            process.arguments = arguments + ["-quiet"]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw FileSystemError.notWritable(FileItem.ID(arguments.joined(separator: " ")))
            }
        }

        @Test func movingAFolderToAnotherVolumeKeepsItsExtendedAttributes() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("Project")
            try ExtendedAttribute.write("kept", to: directory.url("Project"))
            try await withVolume(in: directory) { volume in
                let runner = FileOperationRunner()
                let project = try await runner.item(at: FileItem.ID(directory.url("Project").path))

                try await runner.transfer(
                    [project], to: FileItem.ID(volume.path), mode: .move,
                    resolver: ScriptedResolver())

                #expect(ExtendedAttribute.read(volume.appendingPathComponent("Project")) == "kept")
            }
        }

        @Test func movesAFileToAnotherVolumeByCopyingAndRemovingTheSource() async throws {
            let directory = try TempDirectory()
            let source = try directory.makeFile("Notes.md", contents: "hello")
            try await withVolume(in: directory) { volume in
                let runner = FileOperationRunner()
                let notes = try await runner.item(at: FileItem.ID(source.path))
                let target = try await runner.item(at: FileItem.ID(volume.path))
                #expect(notes.volume != target.volume)

                try await runner.transfer(
                    [notes], to: target.id, mode: .move, resolver: ScriptedResolver())

                #expect(!FileManager.default.fileExists(atPath: source.path))
                let moved = volume.appendingPathComponent("Notes.md")
                #expect(try String(contentsOf: moved, encoding: .utf8) == "hello")
            }
        }

        @Test func keepsTheSourceWhenTheCopyFails() async throws {
            let directory = try TempDirectory()
            let source = directory.url("Large.bin")
            try Data(count: Self.tooLargeBytes).write(to: source)
            try await withVolume(in: directory) { volume in
                let runner = FileOperationRunner()
                let large = try await runner.item(at: FileItem.ID(source.path))

                await #expect(throws: (any Error).self) {
                    try await runner.transfer(
                        [large], to: FileItem.ID(volume.path), mode: .move,
                        resolver: ScriptedResolver()
                    )
                }

                #expect(FileManager.default.fileExists(atPath: source.path))
                let leftovers = try FileManager.default.contentsOfDirectory(atPath: volume.path)
                    .filter { $0.hasPrefix(".treewise-partial-") || $0 == "Large.bin" }
                #expect(leftovers.isEmpty)
            }
        }

        @Test func reportsTooLittleSpaceOnTheTargetVolume() async throws {
            let directory = try TempDirectory()
            let source = directory.url("Large.bin")
            try Data(count: Self.tooLargeBytes).write(to: source)
            try await withVolume(in: directory) { volume in
                let runner = FileOperationRunner()
                let large = try await runner.item(at: FileItem.ID(source.path))

                await #expect(throws: FileSystemError.notEnoughSpace(large.id)) {
                    try await runner.transfer(
                        [large], to: FileItem.ID(volume.path), mode: .copy,
                        resolver: ScriptedResolver()
                    )
                }
            }
        }

        @Test func reportsProgressInsideALargeFile() async throws {
            let directory = try TempDirectory()
            let source = directory.url("Large.bin")
            try Data(count: Self.largeBytes).write(to: source)
            try await withVolume(in: directory) { volume in
                let runner = FileOperationRunner()
                let large = try await runner.item(at: FileItem.ID(source.path))
                let seen = Mutex<[Int64]>([])

                _ = try await runner.copy(
                    large, into: FileItem.ID(volume.path), as: "Large.bin",
                    onFile: { _, copied in seen.withLock { $0.append(copied) } },
                    control: TransferControl())

                let inside = seen.withLock { $0 }.filter { $0 > 0 && $0 < Int64(Self.largeBytes) }
                #expect(!inside.isEmpty, "progress while the file copies")
            }
        }

        @Test func stopsInsideALargeFileAndLeavesNothingBehind() async throws {
            let directory = try TempDirectory()
            let source = directory.url("Large.bin")
            try Data(count: Self.largeBytes).write(to: source)
            try await withVolume(in: directory) { volume in
                let runner = FileOperationRunner()
                let large = try await runner.item(at: FileItem.ID(source.path))
                let control = TransferControl()

                await #expect(throws: FileSystemError.cancelled) {
                    try await runner.copy(
                        large, into: FileItem.ID(volume.path), as: "Large.bin",
                        onFile: { _, copied in if copied > 0 { control.stop() } }, control: control)
                }

                #expect(FileManager.default.fileExists(atPath: source.path))
                let leftovers = try FileManager.default.contentsOfDirectory(atPath: volume.path)
                    .filter { $0.hasPrefix(".treewise-partial-") || $0 == "Large.bin" }
                #expect(leftovers.isEmpty)
            }
        }

        @Test func ejectsAVolume() async throws {
            let directory = try TempDirectory()
            try await withVolume(in: directory) { volume in
                try await LocalFileSystem().eject(FileItem.ID(volume.path))
                #expect(!Self.isMounted(volume))
            }
        }

        @Test func theMountTableReportsAMountedVolume() async throws {
            let directory = try TempDirectory()
            let changes = MountTable.changes()
            try await withVolume(in: directory) { volume in
                #expect(await Self.arrives(changes), "the mount table reports the mount")
                #expect(Self.isMounted(volume))
            }
        }

        @Test func theMountTableReportsAnEjectedVolume() async throws {
            let directory = try TempDirectory()
            try await withVolume(in: directory) { volume in
                let changes = MountTable.changes()
                try await LocalFileSystem().eject(FileItem.ID(volume.path))
                #expect(await Self.arrives(changes), "the mount table reports the eject")
                #expect(!Self.isMounted(volume))
            }
        }

        /// Whether the mount table lists `volume`; a disk image attached
        /// with `-nobrowse` is hidden.
        private static func isMounted(_ volume: URL) -> Bool {
            MountTable.mountPoints(includingHidden: true).contains {
                $0.resolvingSymlinksInPath() == volume.resolvingSymlinksInPath()
            }
        }

        /// Whether an event arrives before the deadline.
        private static func arrives(_ events: AsyncStream<Void>) async -> Bool {
            await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    var iterator = events.makeAsyncIterator()
                    return await iterator.next() != nil
                }
                group.addTask {
                    try? await Task.sleep(for: Self.watchDeadline)
                    return false
                }
                let first = await group.next() ?? false
                group.cancelAll()
                return first
            }
        }

        @Test func aWatchedFolderOnAnEjectedVolumeReportsIt() async throws {
            let directory = try TempDirectory()
            try await withVolume(in: directory) { volume in
                let events = DirectoryWatcher().changes(of: FileItem.ID(volume.path))
                try await LocalFileSystem().eject(FileItem.ID(volume.path))
                let ended = await withTaskGroup(of: Bool.self) { group in
                    group.addTask {
                        for await _ in events {}
                        return true
                    }
                    group.addTask {
                        try? await Task.sleep(for: Self.watchDeadline)
                        return false
                    }
                    let first = await group.next() ?? false
                    group.cancelAll()
                    return first
                }
                #expect(ended, "the watch ends when its volume leaves")
            }
        }
    }
#endif
