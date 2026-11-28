/// A path as `git diff` writes it in its headings: as it is, or, when it holds a tab, a
/// newline, a quote, a backslash or (with core.quotePath on) a letter outside ASCII,
/// between quotes with C's escapes and octal bytes.
enum GitQuotedPath {
    private static let octalDigits = 3
    private static let octalBase = 8
    private static let escapes: [Character: UInt8] = [
        "a": 0x07, "b": 0x08, "t": 0x09, "n": 0x0A, "v": 0x0B, "f": 0x0C, "r": 0x0D,
        "\"": 0x22, "\\": 0x5C,
    ]

    /// The path `text` names, without git's `a/` or `b/` before it; `nil` for
    /// `/dev/null`, which stands for no file.
    static func path(_ text: Substring) -> String? {
        let text = text.hasSuffix("\t") ? text.dropLast() : text
        guard text != "/dev/null" else { return nil }
        let name = text.hasPrefix("\"") ? unquoted(text) : String(text)
        return name.hasPrefix("a/") || name.hasPrefix("b/") ? String(name.dropFirst(2)) : name
    }

    /// The two paths of a `diff --git a/… b/…` heading's `rest`, read only where nothing
    /// else names the file, as for a binary file; an unquoted name with spaces is found
    /// as the one both halves share.
    static func headingPath(_ rest: Substring) -> String? {
        if rest.hasPrefix("\""), let end = closingQuote(in: rest) {
            return path(rest[...end])
        }
        // "a/" + name + " b/" + name
        let length = (rest.count - "a/ b/".count) / 2
        guard length > 0 else { return nil }
        return String(rest.dropFirst(2).prefix(length))
    }

    /// The index of the quote that closes the one `text` starts with.
    private static func closingQuote(in text: Substring) -> Substring.Index? {
        var index = text.index(after: text.startIndex)
        while index < text.endIndex {
            if text[index] == "\\" {
                index = text.index(after: index)
            } else if text[index] == "\"" {
                return index
            }
            if index < text.endIndex { index = text.index(after: index) }
        }
        return nil
    }

    /// A quoted name's text: its escapes read, its octal bytes put together as UTF-8.
    private static func unquoted(_ text: Substring) -> String {
        var bytes: [UInt8] = []
        var characters = text.dropFirst().makeIterator()
        while let character = characters.next() {
            if character == "\"" { break }
            guard character == "\\", let next = characters.next() else {
                bytes.append(contentsOf: Array(String(character).utf8))
                continue
            }
            if let byte = escapes[next] {
                bytes.append(byte)
            } else if let first = next.wholeNumberValue, first < octalBase {
                var value = first
                for _ in 1..<octalDigits {
                    guard let digit = characters.next()?.wholeNumberValue else { break }
                    value = value * octalBase + digit
                }
                bytes.append(UInt8(truncatingIfNeeded: value))
            } else {
                bytes.append(contentsOf: Array(String(next).utf8))
            }
        }
        // swiftlint:disable:next optional_data_string_conversion - a name that is no UTF-8 still shows
        return String(decoding: bytes, as: UTF8.self)
    }
}
