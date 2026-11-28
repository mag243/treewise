/// A changed part of a file, with the lines around it, as a diff's `@@` heading starts one
/// (ADR 0153).
public struct GitDiffHunk: Hashable, Sendable {
    /// One line of a hunk.
    public struct Line: Hashable, Sendable {
        /// What the line is in the change.
        public enum Kind: Hashable, Sendable {
            /// The same before and after, shown around a change.
            case context
            /// Only after.
            case added
            /// Only before.
            case removed
        }

        /// What the line is in the change.
        public let kind: Kind
        /// The line's text, without its kind's mark or its newline.
        public let text: String
        /// Its number before the change; `nil` for an added line.
        public let oldNumber: Int?
        /// Its number after the change; `nil` for a removed line.
        public let newNumber: Int?
        /// Whether it is a file's last line without a newline after it.
        public var endsWithoutNewline: Bool

        /// Creates a line.
        public init(
            kind: Kind, text: String, oldNumber: Int?, newNumber: Int?,
            endsWithoutNewline: Bool = false
        ) {
            self.kind = kind
            self.text = text
            self.oldNumber = oldNumber
            self.newNumber = newNumber
            self.endsWithoutNewline = endsWithoutNewline
        }
    }

    /// The number of its first line before the change.
    public let oldStart: Int
    /// The number of its first line after the change.
    public let newStart: Int
    /// The text git puts after the heading, such as the function the part is in; empty
    /// without one.
    public let section: String
    /// Its lines, in order.
    public var lines: [Line]

    /// Creates a hunk.
    public init(oldStart: Int, newStart: Int, section: String, lines: [Line] = []) {
        self.oldStart = oldStart
        self.newStart = newStart
        self.section = section
        self.lines = lines
    }
}
