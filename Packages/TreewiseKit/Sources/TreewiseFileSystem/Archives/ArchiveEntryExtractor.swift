#if os(macOS)
    import Foundation
    import TreewiseCore

    /// What to extract of an archive: one entry and what is below it, or all.
    struct ArchiveSelection: Sendable {
        /// The archive.
        let archive: FileItem.ID
        /// The name to ask `tar` for, or `nil` for all of the archive.
        let storedName: String?
        /// Where the selection lands below the folder extracted into.
        let path: String

        /// The archive on disk.
        var archiveURL: URL { URL(fileURLWithPath: archive.rawValue) }

        /// Selects a place, or returns `nil` when the archive has no such path.
        init?(_ place: ArchivePath, in tree: ArchiveTree) {
            archive = place.archive
            path = place.entry
            guard !place.isTopLevel else {
                storedName = nil
                return
            }
            guard let node = tree.node(at: place.entry) else { return nil }
            let stored = node.entry?.storedName ?? node.path
            storedName = stored.hasSuffix("/") ? String(stored.dropLast()) : stored
        }

        /// The whole of an archive.
        init(wholeOf archive: FileItem.ID) {
            self.archive = archive
            storedName = nil
            path = ""
        }
    }

    /// Extracts a part of an archive with the protections of `ArchiveExtractor`
    /// (ADR 0076).
    enum ArchiveEntryExtractor {
        private static let isoExtension = "iso"
        private static let outputName = "output"
        private static let namesFile = "names"
        /// What `tar` would read as a pattern in a list of names.
        private static let patternCharacters: Set<Character> = ["\\", "[", "]", "*", "?"]

        /// Extracts `selection` into `output`, which exists, keeping its path.
        /// `onEntry` hears each entry's name. `temporaryFolder` also holds the
        /// list of names.
        static func extract(
            _ selection: ArchiveSelection, into output: URL, temporaryFolder: URL,
            control: TransferControl, onEntry: (String) -> Void
        ) throws {
            var arguments = [
                "--passphrase", ArchiveExtractor.placeholderPassphrase, "-xvf",
                selection.archiveURL.path, "-C", output.path,
            ]
            if let name = selection.storedName {
                let names = temporaryFolder.appendingPathComponent(namesFile + UUID().uuidString)
                try Data((pattern(for: name) + "\0").utf8).write(to: names)
                arguments += ["--null", "-T", names.path]
            }
            let outcome = try TarProcess.run(
                arguments, temporaryFolder: temporaryFolder, control: control
            ) { line in
                guard TarProcess.isEntry(line), !TarProcess.isFailure(line) else { return }
                onEntry(TarProcess.entryName(line))
            }
            guard outcome.succeeded else {
                throw TarFailure.extractionError(
                    outcome.failures, archive: selection.archive,
                    folder: FileItem.ID(output.path))
            }
            if selection.archiveURL.pathExtension.lowercased() == isoExtension {
                ArchiveWorkspace.grantWrite(under: output, toFiles: true)
            }
        }

        /// Copies `selection` to `target`, which must not exist yet.
        ///
        /// Postcondition: all of the selection is at `target`, or nothing new is.
        static func copy(
            _ selection: ArchiveSelection, to target: URL, control: TransferControl,
            onEntry: (String) -> Void
        ) throws {
            let folder = target.deletingLastPathComponent()
            guard !FileManager.default.fileExists(atPath: target.path) else {
                throw FileSystemError.alreadyExists(FileItem.ID(target.path))
            }
            let workspace = try ArchiveWorkspace(in: folder)
            defer { workspace.discard() }
            let output = workspace.url.appendingPathComponent(outputName)
            do {
                try FileManager.default.createDirectory(
                    at: output, withIntermediateDirectories: false)
                try extract(
                    selection, into: output, temporaryFolder: workspace.url, control: control,
                    onEntry: onEntry)
                try FileManager.default.moveItem(
                    at: selection.path.isEmpty
                        ? output : output.appendingPathComponent(selection.path), to: target)
            } catch let error as FileSystemError {
                throw error
            } catch {
                throw TrashService.error(error, for: FileItem.ID(folder.path))
            }
        }

        /// A name as `tar` matches it literally. Names in a list are patterns.
        private static func pattern(for name: String) -> String {
            String(name.flatMap { patternCharacters.contains($0) ? ["\\", $0] : [$0] })
        }
    }
#endif
