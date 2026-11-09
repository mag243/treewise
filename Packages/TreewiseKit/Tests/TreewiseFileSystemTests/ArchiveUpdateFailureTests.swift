#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// A change to an archive that cannot be made leaves it as it was (ADR 0078).
    @Suite struct ArchiveUpdateFailureTests: ArchiveTesting {
        @Test func aStopLeavesTheArchiveAsItWas() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let before = try Data(contentsOf: directory.url("Photos.zip"))
            let control = TransferControl()
            control.stop()

            await #expect(throws: FileSystemError.cancelled) {
                try await apply(
                    .remove(["Photos/a.txt"]), to: "Photos.zip", in: directory, control: control)
            }

            #expect(try Data(contentsOf: directory.url("Photos.zip")) == before)
            #expect(!(try names(directory, in: ".").contains { $0.hasPrefix(".treewise") }))
        }

        @Test func aDamagedArchiveIsNotChanged() async throws {
            let directory = try TempDirectory()
            try writeDamaged(directory)
            let before = try Data(contentsOf: directory.url("Broken.zip"))

            await #expect(throws: FileSystemError.archiveDamaged(id(directory, "Broken.zip"))) {
                try await apply(.remove(["src.bin"]), to: "Broken.zip", in: directory)
            }

            #expect(try Data(contentsOf: directory.url("Broken.zip")) == before)
            #expect(!(try names(directory, in: ".").contains { $0.hasPrefix(".treewise") }))
        }

        @Test func aProtectedZipIsNotChanged() async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            try directory.makeFile("src/secret.txt", contents: "hidden")
            try ArchiveFixtures.tar([
                "--format", "zip", "--options", "zip:encryption=traditional", "--passphrase", "pw",
                "-cf", directory.url("Locked.zip").path, "-C", directory.url("src").path,
                "secret.txt",
            ])
            let before = try Data(contentsOf: directory.url("Locked.zip"))

            await #expect(
                throws: FileSystemError.archivePasswordProtected(id(directory, "Locked.zip"))
            ) {
                try await apply(.newFolder("Fresh"), to: "Locked.zip", in: directory)
            }

            #expect(try Data(contentsOf: directory.url("Locked.zip")) == before)
        }

        @Test func aFormatThatCannotChangeIsRefused() async throws {
            let directory = try TempDirectory()
            try #require(Data(base64Encoded: ArchiveFixtures.rar5)).write(
                to: directory.url("Old.rar"))

            await #expect(throws: FileSystemError.archiveReadOnly) {
                try await apply(.newFolder("Fresh"), to: "Old.rar", in: directory)
            }
        }

        @Test func anArchiveOutsideTheBoundaryIsRefused() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let inner = try directory.makeFolder("inner")
            let archive = id(directory, "Photos.zip")

            await #expect(throws: FileSystemError.outsideBoundary(archive)) {
                try await runner(directory, boundary: [inner]).apply(
                    .newFolder("Fresh"), to: archive, onProgress: { _ in },
                    control: TransferControl())
            }
        }

        @Test func aListingSeesTheChange() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let runner = runner(directory)
            let top = ArchivePath(archive: id(directory, "Photos.zip"))
            _ = try await runner.contents(of: top.id)

            try await runner.apply(
                .newFolder("Fresh"), to: top.archive, onProgress: { _ in },
                control: TransferControl())

            #expect(try await runner.contents(of: top.id).contains { $0.name == "Fresh" })
        }
    }
#endif
