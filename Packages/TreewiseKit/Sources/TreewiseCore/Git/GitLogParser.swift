import Foundation

/// Reads the output of `git log -z --name-status --format=<format>` into commits as it
/// comes, so the first commits of a long history show while git is still reading the
/// rest (ADR 0153).
///
/// Each commit is a record that starts with an RS (0x1E) byte. Its fields are separated
/// by a US (0x1F) byte, which no name, hash or date holds; the last one ends the message,
/// and the item's change follows: its status, then its path, or for a rename or copy its
/// old and new path, each ending in a 0 byte. A record git cannot have written, or whose
/// text is no UTF-8, is left out without losing the others.
public struct GitLogParser: Sendable {
    /// The `--format` the parser reads: hash, parents, author, e-mail, time, message.
    public static let format = "%x1E%H%x1F%P%x1F%an%x1F%ae%x1F%at%x1F%B%x1F"

    private static let recordStart = UInt8(0x1E)
    private static let fieldEnd = UInt8(0x1F)
    /// The fields before the message: hash, parents, author, e-mail and time.
    private static let fieldsBeforeMessage = 5

    /// What came after the last whole record; a record is whole when the next one starts
    /// or git ends.
    private var pending = Data()

    /// Creates a parser with nothing read.
    public init() {}

    /// Reads the next part of git's output.
    ///
    /// - Returns: the commits whose records it completed, in git's order.
    public mutating func append(_ data: Data) -> [GitCommit] {
        pending.append(data)
        guard let last = pending.lastIndex(of: Self.recordStart) else { return [] }
        let whole = pending[pending.startIndex..<last]
        pending = Data(pending[last...])
        return Self.commits(in: whole)
    }

    /// Reads what is left once git has ended.
    ///
    /// - Returns: the commit of the last record, if it holds one.
    public mutating func finish() -> [GitCommit] {
        defer { pending = Data() }
        return Self.commits(in: pending)
    }

    private static func commits(in data: Data) -> [GitCommit] {
        data.split(separator: recordStart, omittingEmptySubsequences: true).compactMap(commit)
    }

    private static func commit(in record: Data.SubSequence) -> GitCommit? {
        guard let end = record.lastIndex(of: fieldEnd),
            let text = String(bytes: record[record.startIndex..<end], encoding: .utf8)
        else { return nil }
        let fields = text.split(
            separator: "\u{1F}", maxSplits: fieldsBeforeMessage, omittingEmptySubsequences: false)
        guard fields.count == fieldsBeforeMessage + 1, !fields[0].isEmpty,
            let time = TimeInterval(fields[4])
        else { return nil }
        let change = change(in: record[record.index(after: end)...])
        return GitCommit(
            id: String(fields[0]), parents: fields[1].split(separator: " ").map(String.init),
            author: String(fields[2]), email: String(fields[3]),
            date: Date(timeIntervalSince1970: time),
            message: String(fields[5].reversed().drop { $0 == "\n" }.reversed()),
            path: change.path, renamedFrom: change.renamedFrom)
    }

    /// The item's change after the message: `\0\n`, its status and one path, or two for a
    /// rename or copy, each ending in a 0 byte; nothing for a commit without a change of
    /// its own.
    private static func change(in data: Data.SubSequence) -> (path: String?, renamedFrom: String?) {
        let fields = data.split(separator: 0, omittingEmptySubsequences: true)
            .compactMap { String(bytes: $0, encoding: .utf8) }
            .filter { $0 != "\n" }
        let status = fields.first.map { $0.trimmingCharacters(in: .newlines) }
        guard let status, fields.count >= 2 else { return (nil, nil) }
        if fields.count >= 3, status.hasPrefix("R") || status.hasPrefix("C") {
            return (fields[2], status.hasPrefix("R") ? fields[1] : nil)
        }
        return (fields[1], nil)
    }
}
