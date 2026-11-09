#if os(macOS)
    import Foundation
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// What the tests of archives share, always inside a TempDirectory.
    protocol ArchiveTesting {}

    extension ArchiveTesting {
        var manager: FileManager { .default }

        func runner(_ directory: TempDirectory, boundary: [URL]? = nil)
            -> FileOperationRunner
        {
            FileOperationRunner(locations: locations(directory, boundary: boundary))
        }

        /// Locations whose Trash is a folder of `directory`: a test never touches
        /// the real one.
        func locations(_ directory: TempDirectory, boundary: [URL]? = nil)
            -> LocalFileSystem.Locations
        {
            let trash = directory.url("trash")
            return .init(
                home: directory.url("home"), applications: directory.url("Applications"),
                boundary: boundary,
                moveToTrash: { file in
                    try FileManager.default.createDirectory(
                        at: trash, withIntermediateDirectories: true)
                    try FileManager.default.moveItem(
                        at: file,
                        to: trash.appendingPathComponent(UUID().uuidString + file.lastPathComponent)
                    )
                })
        }

        func id(_ directory: TempDirectory, _ path: String) -> FileItem.ID {
            FileItem.ID(directory.path + "/" + path)
        }

        /// Extracts `archive` into the folder `to` as `Out`.
        @discardableResult
        func extract(
            _ directory: TempDirectory, _ archive: String,
            control: TransferControl = TransferControl(),
            onProgress: @escaping ArchiveProgressHandler = { _ in }
        ) async throws -> FileItem {
            try directory.makeFolder("to")
            let runner = runner(directory)
            return try await runner.extract(
                try await runner.item(at: id(directory, archive)), into: id(directory, "to"),
                as: "Out", onProgress: onProgress, control: control)
        }

        @discardableResult
        func apply(
            _ edit: ArchiveEdit, to name: String, in directory: TempDirectory,
            control: TransferControl = TransferControl()
        ) async throws -> UndoRecord {
            try await runner(directory).apply(
                edit, to: id(directory, name), onProgress: { _ in }, control: control)
        }

        func names(_ directory: TempDirectory, in folder: String) throws -> [String] {
            try manager.contentsOfDirectory(atPath: directory.url(folder).path).sorted()
        }

        func makeArchive(
            _ directory: TempDirectory, _ name: String = "Photos.zip",
            options: [String] = ["--format", "zip"]
        ) throws {
            try ArchiveFixtures.makeTree(in: directory)
            try ArchiveFixtures.tar(
                options + [
                    "-cf", directory.url(name).path, "-C", directory.url("src").path, "Photos",
                ]
            )
        }

        func writeDamaged(_ directory: TempDirectory) throws {
            try directory.makeFile("src.bin", contents: String(repeating: "abcdefgh", count: 9000))
            try ArchiveFixtures.tar([
                "--format", "zip", "-cf", directory.url("whole.zip").path, "-C", directory.path,
                "src.bin",
            ])
            try Data(contentsOf: directory.url("whole.zip")).prefix(120)
                .write(to: directory.url("Broken.zip"))
        }
    }
#endif
