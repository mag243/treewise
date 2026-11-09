#if os(macOS)
    import Foundation
    import TreewiseCore

    /// One change to an archive: what is staged, what the new archive should
    /// hold, and how `zip` or `tar` makes it (ADR 0078).
    struct ArchiveUpdateRun {
        private static let zipExecutable = "/usr/bin/zip"
        private static let zipExtension = "zip"
        private static let leftovers: Set<String> = [".DS_Store", "__MACOSX"]
        private static let leftoverPrefix = "._"
        private static let cleanOptions = ["--no-mac-metadata", "--no-xattrs", "--no-fflags"]
        /// What `tar` and `zip` would read as a pattern in a name.
        private static let patternCharacters: Set<Character> = ["\\", "[", "]", "*", "?"]
        /// What a regular expression of `-s` would read as more than itself.
        private static let regexCharacters: Set<Character> = [
            "\\", ".", "[", "]", "*", "^", "$",
        ]
        private static let ruleDelimiter = "\u{1}"
        /// The largest file read to tell that a zip is protected, in bytes.
        private static let largestProbe: Int64 = 1_000_000
        /// The folder what is added goes through for `tar`, so that the list of
        /// what goes does not also catch what comes in under the same name.
        private static let addedFolder = "treewise-added"
        private static let tarFormats: [(suffix: String, options: [String])] = [
            (".tar.gz", ["-z"]), (".tgz", ["-z"]), (".tar.bz2", ["-j"]), (".tar.xz", ["-J"]),
            (".tar", ["--format", "pax"]), (".7z", ["--format", "7zip"] + cleanOptions),
            (".zip", ["--format", "zip"] + cleanOptions),
        ]

        let job: ArchiveUpdater.Job
        let workspace: ArchiveWorkspace
        let control: TransferControl
        /// What the new archive should hold.
        let expected: Set<String>
        private let staging: URL
        /// The paths in `staging` that go in, folders with a trailing slash.
        private let stagedNames: [String]

        /// Prepares a change: looks whether it can be done and stages what goes in.
        init(
            job: ArchiveUpdater.Job, workspace: ArchiveWorkspace, stagingName: String,
            control: TransferControl
        ) throws {
            self.job = job
            self.workspace = workspace
            self.control = control
            staging = workspace.url.appendingPathComponent(stagingName)
                .appendingPathComponent(Self.addedFolder)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            stagedNames = try Self.stage(job.edit, in: staging)
            let added = stagedNames.map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
            expected = job.tree.paths(after: Self.change(of: job.edit, added: added))
            try refuseIfProtected()
        }

        /// Whether `zip` can do this change: adding, removing and new folders in
        /// a zip, for names it can read from a list of lines.
        var usesZip: Bool {
            guard job.url.pathExtension.lowercased() == Self.zipExtension else { return false }
            if case .relocate = job.edit { return false }
            return !stagedNames.contains { $0.contains("\n") }
                && !namesToDrop.contains { $0.contains("\n") }
        }

        /// Clones the archive and changes the clone with `zip`.
        ///
        /// - Returns: whether `zip` ended without an error.
        func updateWithZip(_ candidate: URL) throws -> Bool {
            try FileManager.default.copyItem(at: job.url, to: candidate)
            if !namesToDrop.isEmpty {
                let list = try writeList(namesToDrop.map(Self.literalPattern), named: "drop")
                guard try runZip(["-q", "-d", candidate.path, "-@"], input: list, in: nil) else {
                    return false
                }
            }
            guard !stagedNames.isEmpty else { return true }
            let list = try writeList(stagedNames, named: "add")
            return try runZip(["-q", "-X", "-y", candidate.path, "-@"], input: list, in: staging)
        }

        /// Makes the new archive with `tar`, which copies the old archive's
        /// entries, without the ones that go, and adds what is staged.
        func updateWithTar(_ candidate: URL, onProgress: ArchiveProgressHandler) throws {
            let arguments = try tarArguments(for: candidate)
            let total = expected.count
            var completed = 0
            let outcome = try TarProcess.run(
                arguments, temporaryFolder: workspace.url, control: control
            ) { line in
                guard TarProcess.isEntry(line), !TarProcess.isFailure(line) else { return }
                completed += 1
                onProgress(
                    ArchiveProgress(
                        completedEntries: completed, totalEntries: total,
                        currentName: TarProcess.entryName(line)))
            }
            guard outcome.succeeded else {
                throw TarFailure.extractionError(
                    outcome.failures, archive: job.archive,
                    folder: FileItem.ID(job.url.deletingLastPathComponent().path))
            }
        }

        private func tarArguments(for candidate: URL) throws -> [String] {
            var arguments = formatOptions + ["-cvf", candidate.path]
            if !namesToDrop.isEmpty {
                // Anchored: a pattern also matches from any folder on down.
                let list = try writeList(
                    namesToDrop.map { "^" + Self.literalPattern($0) }, named: "exclude")
                arguments += ["-X", list.path]
            }
            if case .relocate(let source, let target) = job.edit,
                let rule = relocationRule(from: source, to: target)
            {
                arguments += ["-s", rule]
            }
            if !stagedNames.isEmpty {
                let names = workspace.url.appendingPathComponent("names")
                let listed = stagedNames.map { Self.addedFolder + "/" + $0 + "\0" }
                try Data(listed.joined().utf8).write(to: names)
                let rule =
                    Self.ruleDelimiter + "^" + Self.addedFolder + "/" + Self.ruleDelimiter
                    + Self.ruleDelimiter + "HS"
                arguments += [
                    "-s", rule, "-C", staging.deletingLastPathComponent().path, "-n", "--null",
                    "-T", names.path,
                ]
            }
            // tar reads no more options after the first name.
            arguments.append("@" + job.url.path)
            return arguments
        }

        // MARK: What changes

        private static func change(of edit: ArchiveEdit, added: [String]) -> ArchiveChange {
            switch edit {
            case .add, .newFolder: .add(added)
            case .remove(let paths): .remove(paths)
            case .relocate(let source, let target): .relocate(from: source, to: target)
            }
        }

        /// The stored names of what goes: what is removed, or replaced by an addition.
        private var namesToDrop: [String] {
            switch job.edit {
            case .remove(let paths):
                return paths.flatMap(job.tree.storedNames(atOrBelow:)).map(Self.withoutSlash)
            case .add:
                return stagedNames.filter { !$0.hasSuffix("/") }
                    .compactMap { job.tree.node(at: $0)?.entry?.storedName }
                    .map(Self.withoutSlash)
            case .relocate, .newFolder:
                return []
            }
        }

        private var formatOptions: [String] {
            let name = job.url.lastPathComponent.lowercased()
            return Self.tarFormats.first { name.hasSuffix($0.suffix) }?.options ?? []
        }

        /// A rule for `-s` that gives a path, and what is below it, its new place.
        /// `H` and `S` leave what a link points to alone.
        private func relocationRule(from source: String, to target: String) -> String? {
            guard let prefix = storedPrefix(of: source) else { return nil }
            let delimiter = Self.ruleDelimiter
            let pattern = "^" + Self.escaped(prefix, Self.regexCharacters) + "\\(/.*\\)\\{0,1\\}$"
            // The replacement is literal to tar, but for a backslash and a digit.
            return delimiter + pattern + delimiter + target + "\\1" + delimiter + "HS"
        }

        /// How the archive stores a path's start, which may begin with `./`.
        private func storedPrefix(of path: String) -> String? {
            let parts = path.split(separator: "/").count
            guard let stored = job.tree.storedNames(atOrBelow: path).first else { return nil }
            let storedParts = stored.split(separator: "/", omittingEmptySubsequences: false)
            let lead = storedParts.first == "." ? 1 : 0
            return storedParts.prefix(lead + parts).joined(separator: "/")
        }

        // MARK: Staging

        /// Puts what goes in at its place in `staging`.
        ///
        /// - Returns: the paths to add, without Mac leftovers, folders with a slash.
        private static func stage(_ edit: ArchiveEdit, in staging: URL) throws -> [String] {
            switch edit {
            case .add(let additions):
                for addition in additions {
                    let target = staging.appendingPathComponent(addition.path)
                    try FileManager.default.createDirectory(
                        at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: addition.source, to: target)
                }
            case .newFolder(let path):
                try FileManager.default.createDirectory(
                    at: staging.appendingPathComponent(path), withIntermediateDirectories: true)
            case .remove, .relocate:
                return []
            }
            return stagedPaths(in: staging)
        }

        private static func stagedPaths(in staging: URL) -> [String] {
            let base = staging.resolvingSymlinksInPath().path + "/"
            var paths: [String] = []
            let entries = FileManager.default.enumerator(
                at: staging, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            while let entry = entries?.nextObject() as? URL {
                let name = entry.lastPathComponent
                if leftovers.contains(name) || name.hasPrefix(leftoverPrefix) {
                    entries?.skipDescendants()
                    continue
                }
                let values = try? entry.resourceValues(forKeys: [
                    .isDirectoryKey, .isSymbolicLinkKey,
                ])
                let isFolder = values?.isDirectory == true && values?.isSymbolicLink != true
                let path = String(entry.resolvingSymlinksInPath().path.dropFirst(base.count))
                paths.append(isFolder ? path + "/" : relative(entry, to: staging, fallback: path))
            }
            return paths
        }

        /// The path of a link keeps its own place, not where it points.
        private static func relative(_ entry: URL, to staging: URL, fallback: String) -> String {
            let parts = entry.standardizedFileURL.pathComponents
            let base = staging.standardizedFileURL.pathComponents
            guard parts.starts(with: base) else { return fallback }
            return parts.dropFirst(base.count).joined(separator: "/")
        }

        // MARK: Tools

        /// A protected zip can be changed by `zip` without its password, which
        /// would leave a mix: its smallest file tells, at little cost. A zip
        /// whose smallest file is large goes unchecked, as reading it is not.
        private func refuseIfProtected() throws {
            guard job.url.pathExtension.lowercased() == Self.zipExtension,
                let path = job.tree.smallestFile,
                let entry = job.tree.node(at: path)?.entry,
                entry.size <= Self.largestProbe
            else { return }
            let stored = entry.storedName
            let list = try writeList([Self.literalPattern(stored)], named: "probe")
            let outcome = try TarProcess.run(
                [
                    "--passphrase", ArchiveExtractor.placeholderPassphrase, "-xvOf", job.url.path,
                    "-T", list.path,
                ],
                temporaryFolder: workspace.url, control: control
            ) { _ in }
            guard !outcome.succeeded else { return }
            throw TarFailure.extractionError(
                outcome.failures, archive: job.archive, folder: FileItem.ID(job.url.path))
        }

        private func runZip(_ arguments: [String], input: URL, in folder: URL?) throws -> Bool {
            let tool = TarProcess.Tool(
                executable: Self.zipExecutable, workingDirectory: folder, input: input)
            return try TarProcess.run(
                arguments, temporaryFolder: workspace.url, control: control, tool: tool
            ) { _ in }.succeeded
        }

        private func writeList(_ lines: [String], named name: String) throws -> URL {
            let url = workspace.url.appendingPathComponent(name)
            try Data(lines.joined(separator: "\n").appending("\n").utf8).write(to: url)
            return url
        }

        private static func withoutSlash(_ name: String) -> String {
            name.hasSuffix("/") ? String(name.dropLast()) : name
        }

        private static func literalPattern(_ name: String) -> String {
            escaped(name, patternCharacters)
        }

        private static func escaped(_ text: String, _ characters: Set<Character>) -> String {
            String(text.flatMap { characters.contains($0) ? ["\\", $0] : [$0] })
        }
    }
#endif
