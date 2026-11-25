import Foundation

extension GitRepositoryStatus {
    /// The fields before the path in an ordinary change, a rename or copy, and a conflict.
    private static let fieldsBeforePath: [UInt8: Int] = [
        UInt8(ascii: "1"): 8, UInt8(ascii: "2"): 9, UInt8(ascii: "u"): 10,
    ]
    /// The characters of a short hash, as git shows one by default.
    private static let shortHashLength = 7

    /// Reads the output of `git status --porcelain=v2 --branch -z --ignored`.
    ///
    /// Every record ends in a 0 byte, so a name may hold spaces and newlines; a rename's
    /// record is followed by its old name as one more. A record whose name is no UTF-8,
    /// or of a kind git adds later, is left out without losing the others.
    public init(porcelain data: Data) {
        self.init()
        var oid: String?
        var records = data.split(separator: 0, omittingEmptySubsequences: true).makeIterator()
        while let bytes = records.next() {
            guard let kind = bytes.first else { continue }
            let record = String(bytes: bytes, encoding: .utf8)
            if kind == UInt8(ascii: "2") {
                // A rename's old name follows as a record of its own, never read as one.
                let old = records.next().flatMap { String(bytes: $0, encoding: .utf8) }
                guard let record else { continue }
                readChange(record, kind: kind)
                if let old { mark(nil, at: old) }
            } else if let record {
                read(record, kind: kind, oid: &oid)
            }
        }
        if case .detached = head, let oid {
            head = .detached(String(oid.prefix(Self.shortHashLength)))
        }
    }

    /// A record other than a rename's.
    private mutating func read(_ record: String, kind: UInt8, oid: inout String?) {
        switch kind {
        case UInt8(ascii: "#"): readHeader(record, oid: &oid)
        case UInt8(ascii: "?"): readWhole(record, as: .new)
        case UInt8(ascii: "!"): readWhole(record, as: .ignored)
        case UInt8(ascii: "1"), UInt8(ascii: "u"): readChange(record, kind: kind)
        default: return
        }
    }

    /// A `# branch.…` header; other headers, such as `# stash`, are left alone.
    private mutating func readHeader(_ record: String, oid: inout String?) {
        let fields = record.split(separator: " ")
        guard fields.count >= 3 else { return }
        switch fields[1] {
        case "branch.oid": oid = String(fields[2])
        case "branch.head":
            head = fields[2] == "(detached)" ? .detached("") : .branch(String(fields[2]))
        // Git names the upstream, then counts against it only when it is still there.
        case "branch.upstream": upstream = upstream ?? .gone
        case "branch.ab":
            guard fields.count >= 4, let ahead = Int(fields[2].dropFirst()),
                let behind = Int(fields[3].dropFirst())
            else { return }
            upstream = .following(ahead: ahead, behind: behind)
        default: return
        }
    }

    /// An untracked or ignored item: `? path` or `! path`, a folder git lists whole
    /// ending in `/`.
    private mutating func readWhole(_ record: String, as state: GitItemState) {
        let path = record.dropFirst(2)
        guard !path.isEmpty else { return }
        if path.hasSuffix("/") {
            mark(state, at: String(path.dropLast()), isFolder: true)
        } else {
            mark(state, at: String(path))
        }
    }

    /// A tracked item that changed: its two status letters, staged and in the working
    /// tree, then fields up to its path.
    private mutating func readChange(_ record: String, kind: UInt8) {
        guard let count = Self.fieldsBeforePath[kind] else { return }
        let fields = record.split(
            separator: " ", maxSplits: count, omittingEmptySubsequences: false)
        guard fields.count == count + 1 else { return }
        let letters = Array(fields[1])
        let path = String(fields[count])
        if kind == UInt8(ascii: "u") {
            mark(.conflict, at: path)
        } else if letters.contains("D") {
            mark(nil, at: path)
        } else if kind == UInt8(ascii: "2") || letters.first == "A" {
            mark(.new, at: path)
        } else {
            mark(.modified, at: path)
        }
    }
}
