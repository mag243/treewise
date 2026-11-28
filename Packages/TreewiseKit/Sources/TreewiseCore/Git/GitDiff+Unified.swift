import Foundation

extension GitDiff {
    /// Reads the output of `git diff` or `git show` with `--no-color` and `-M`.
    ///
    /// A file starts at its `diff --git` heading; its `---` and `+++` lines, its rename
    /// lines and its `Binary files … differ` line say what it is, and each `@@` heading
    /// starts a hunk, whose counts say how many lines belong to it, so a removed line
    /// that starts with `--` is not read as a heading. A line that is no UTF-8 is read as
    /// well as it can be.
    public init(unified data: Data) {
        var reader = UnifiedDiffReader()
        var lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)
        if lines.last?.isEmpty == true { lines.removeLast() }
        for line in lines {
            // swiftlint:disable:next optional_data_string_conversion - a line that is no UTF-8 still shows
            reader.read(String(decoding: line, as: UTF8.self))
        }
        self.init(files: reader.finish())
    }
}

/// The state of reading a unified diff, one line at a time.
private struct UnifiedDiffReader {
    /// What is known so far of the file being read.
    private struct File {
        var headingPath: String?
        var oldPath: String?
        var newPath: String?
        var renamedFrom: String?
        var renamedTo: String?
        var isAdded = false
        var isDeleted = false
        var isBinary = false
        var hunks: [GitDiffHunk] = []
        /// Whether a `---` line was read, after which a `/dev/null` stands for no file.
        var hasOldLine = false
        var hasNewLine = false
    }

    private var files: [GitFileDiff] = []
    private var file: File?
    /// The lines the current hunk still holds before and after the change.
    private var oldLeft = 0
    private var newLeft = 0
    private var nextOld = 0
    private var nextNew = 0

    mutating func read(_ line: String) {
        if oldLeft > 0 || newLeft > 0, readHunkLine(line) { return }
        if line.hasPrefix("\\") {
            markNoNewline()
        } else if line.hasPrefix("diff --git ") {
            close()
            file = File(headingPath: GitQuotedPath.headingPath(line.dropFirst("diff --git ".count)))
        } else if line.hasPrefix("@@ ") {
            startHunk(line)
        } else {
            readHeading(line)
        }
    }

    mutating func finish() -> [GitFileDiff] {
        close()
        return files
    }

    private mutating func readHeading(_ line: String) {
        if line.hasPrefix("--- ") {
            // A file without a `diff --git` heading, as from `diff -u`, starts here.
            if file == nil || file?.hunks.isEmpty == false { close() }
            if file == nil { file = File() }
            file?.hasOldLine = true
            file?.oldPath = GitQuotedPath.path(line.dropFirst(4))
        } else if line.hasPrefix("+++ ") {
            file?.hasNewLine = true
            file?.newPath = GitQuotedPath.path(line.dropFirst(4))
        } else if line.hasPrefix("rename from ") {
            file?.renamedFrom = GitQuotedPath.path(line.dropFirst("rename from ".count))
        } else if line.hasPrefix("rename to ") {
            file?.renamedTo = GitQuotedPath.path(line.dropFirst("rename to ".count))
        } else if line.hasPrefix("new file mode") {
            file?.isAdded = true
        } else if line.hasPrefix("deleted file mode") {
            file?.isDeleted = true
        } else if line.hasPrefix("Binary files ") {
            file?.isBinary = true
        }
    }

    /// Reads a line of the current hunk; `false` for a line that is not one.
    private mutating func readHunkLine(_ line: String) -> Bool {
        guard let mark = line.first else { return false }
        let text = String(line.dropFirst())
        let read: GitDiffHunk.Line
        switch mark {
        case " ":
            read = .init(kind: .context, text: text, oldNumber: nextOld, newNumber: nextNew)
            nextOld += 1
            nextNew += 1
            oldLeft -= 1
            newLeft -= 1
        case "-":
            read = .init(kind: .removed, text: text, oldNumber: nextOld, newNumber: nil)
            nextOld += 1
            oldLeft -= 1
        case "+":
            read = .init(kind: .added, text: text, oldNumber: nil, newNumber: nextNew)
            nextNew += 1
            newLeft -= 1
        default:
            return false
        }
        appendToHunk(read)
        return true
    }

    private mutating func appendToHunk(_ line: GitDiffHunk.Line) {
        guard var hunks = file?.hunks, !hunks.isEmpty else { return }
        hunks[hunks.count - 1].lines.append(line)
        file?.hunks = hunks
    }

    private mutating func markNoNewline() {
        guard var hunks = file?.hunks, var lines = hunks.last?.lines, !lines.isEmpty else {
            return
        }
        lines[lines.count - 1].endsWithoutNewline = true
        hunks[hunks.count - 1].lines = lines
        file?.hunks = hunks
    }

    /// `@@ -old[,count] +new[,count] @@ section`, a count left out being one line.
    private mutating func startHunk(_ line: String) {
        let parts = line.dropFirst(3).split(separator: " ", maxSplits: 3)
        guard parts.count >= 3, parts[2] == "@@", file != nil,
            let old = Self.range(parts[0], mark: "-"), let new = Self.range(parts[1], mark: "+")
        else { return }
        (nextOld, oldLeft, nextNew, newLeft) = (old.start, old.count, new.start, new.count)
        let section = parts.count == 4 ? String(parts[3]) : ""
        file?.hunks.append(GitDiffHunk(oldStart: old.start, newStart: new.start, section: section))
    }

    private static func range(_ text: Substring, mark: Character) -> (start: Int, count: Int)? {
        guard text.first == mark else { return nil }
        let numbers = text.dropFirst().split(separator: ",")
        guard let start = numbers.first.flatMap({ Int($0) }) else { return nil }
        let count = numbers.count > 1 ? Int(numbers[1]) : 1
        return count.map { (start, $0) }
    }

    /// Ends the file being read and keeps it, when it has a path.
    private mutating func close() {
        defer {
            file = nil
            (oldLeft, newLeft) = (0, 0)
        }
        guard let file,
            let path = file.renamedTo ?? file.newPath ?? file.oldPath ?? file.headingPath
        else { return }
        files.append(
            GitFileDiff(
                path: path, change: Self.change(of: file), isBinary: file.isBinary,
                hunks: file.hunks))
    }

    private static func change(of file: File) -> GitFileDiff.Change {
        if let from = file.renamedFrom { return .renamed(from: from) }
        if file.isAdded || (file.hasOldLine && file.oldPath == nil) { return .added }
        if file.isDeleted || (file.hasNewLine && file.newPath == nil) { return .deleted }
        return .modified
    }
}
