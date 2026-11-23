#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseTestSupport

    @testable import TreewiseFileSystem

    /// Whether a zip's entries need a password, read from its central directory, so a
    /// wrong placeholder passphrase that happens to pass zip's one-byte check is not
    /// taken for damage (ADR 0074).
    @Suite struct ZipEncryptionTests {
        private func zip(
            _ directory: TempDirectory, encryption: String? = nil, name: String = "Locked.zip"
        ) throws -> URL {
            try directory.makeFile("a.txt", contents: "secret")
            var options = ["--format", "zip"]
            if let encryption {
                options += ["--options", "zip:encryption=\(encryption)", "--passphrase", "secret"]
            }
            try ArchiveFixtures.tar(
                options + ["-cf", directory.url(name).path, "-C", directory.path, "a.txt"])
            return directory.url(name)
        }

        @Test(arguments: ["traditional", "aes256"])
        func aZipWithAPasswordIsEncrypted(_ encryption: String) throws {
            let directory = try TempDirectory()

            #expect(ZipEncryption.hasEncryptedEntry(at: try zip(directory, encryption: encryption)))
        }

        @Test func aZipWithoutAPasswordIsNot() throws {
            let directory = try TempDirectory()

            #expect(!ZipEncryption.hasEncryptedEntry(at: try zip(directory)))
        }

        @Test func anotherFormatOrNoFileIsNot() throws {
            let directory = try TempDirectory()
            try directory.makeFile("Notes.zip", contents: "This is not an archive at all.")

            #expect(!ZipEncryption.hasEncryptedEntry(at: directory.url("Notes.zip")))
            #expect(!ZipEncryption.hasEncryptedEntry(at: directory.url("Gone.zip")))
        }

        @Test func decompressionFailingInALockedZipNamesThePassword() throws {
            let directory = try TempDirectory()
            let archive = FileItem.ID(try zip(directory, encryption: "traditional").path)

            let error = TarFailure.extractionError(
                ["a.txt: ZIP decompression failed (-3)"], archive: archive,
                folder: FileItem.ID(directory.path))

            #expect(error == .archivePasswordProtected(archive))
        }

        @Test func decompressionFailingInAnOpenZipIsDamage() throws {
            let directory = try TempDirectory()
            let archive = FileItem.ID(try zip(directory).path)

            let error = TarFailure.extractionError(
                ["a.txt: ZIP decompression failed (-3)"], archive: archive,
                folder: FileItem.ID(directory.path))

            #expect(error == .archiveDamaged(archive))
        }
    }
#endif
