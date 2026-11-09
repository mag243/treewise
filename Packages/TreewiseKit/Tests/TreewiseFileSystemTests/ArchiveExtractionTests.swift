#if os(macOS)
    import Foundation
    import Synchronization
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// Extracting archives with the system's `tar` (ADR 0074), inside a TempDirectory.
    @Suite struct ArchiveExtractionTests: ArchiveTesting {
        @Test(arguments: ArchiveFixtures.writable.map(\.name))
        func extractsEveryFormatTarWrites(_ name: String) async throws {
            let directory = try TempDirectory()
            let options = try #require(ArchiveFixtures.writable.first { $0.name == name }).options
            try makeArchive(directory, name, options: options)

            let result = try await extract(directory, name)

            #expect(result.id == id(directory, "to/Out"))
            let folder = directory.url("to/Out/Photos")
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

        @Test(arguments: [ArchiveFixtures.rar4, ArchiveFixtures.rar5])
        func extractsARar(_ base64: String) async throws {
            let directory = try TempDirectory()
            try #require(Data(base64Encoded: base64)).write(to: directory.url("Old.rar"))

            try await extract(directory, "Old.rar")

            #expect(try names(directory, in: "to/Out") == ["hello.txt"])
        }

        @Test func anIsoExtractsWritable() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, "Disc.iso", options: ["--format", "iso9660"])

            try await extract(directory, "Disc.iso")

            for path in ["to/Out", "to/Out/Photos", "to/Out/Photos/empty", "to/Out/Photos/a.txt"] {
                #expect(manager.isWritableFile(atPath: directory.url(path).path), "\(path)")
            }
        }

        @Test func aLinkInAnIsoKeepsWhatItPointsToUnchanged() async throws {
            let directory = try TempDirectory()
            let outside = try directory.makeFile("outside.txt")
            try manager.setAttributes([.posixPermissions: 0o444], ofItemAtPath: outside.path)
            try directory.makeFolder("src")
            try manager.createSymbolicLink(
                atPath: directory.url("src/out").path, withDestinationPath: outside.path)
            try ArchiveFixtures.tar([
                "--format", "iso9660", "-cf", directory.url("Disc.iso").path, "-C",
                directory.url("src").path, "out",
            ])

            try await extract(directory, "Disc.iso")

            #expect(!manager.isWritableFile(atPath: outside.path))
        }

        @Test func reportsEachEntryOfTheTotal() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let seen = Mutex<[ArchiveProgress]>([])

            try await extract(directory, "Photos.zip") { progress in
                seen.withLock { $0.append(progress) }
            }

            let progress = seen.withLock { $0 }
            let entries = 6
            #expect(progress.last?.completedEntries == entries)
            #expect(progress.allSatisfy { $0.totalEntries == entries })
            #expect(progress.map(\.completedEntries) == Array(1...entries))
            #expect(progress.contains { $0.currentName == "Photos/a.txt" })
        }

        @Test func carriesTheArchivesQuarantineToItsContents() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            try ExtendedAttribute.write(
                "0081;00000000;Treewise tests;", to: directory.url("Photos.zip"),
                name: "com.apple.quarantine")

            try await extract(directory, "Photos.zip")

            #expect(
                ExtendedAttribute.read(
                    directory.url("to/Out/Photos/a.txt"), name: "com.apple.quarantine") != nil)
        }
    }
#endif
