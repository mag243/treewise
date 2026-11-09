import Foundation

/// Reading a line of `tar -tv` (ADR 0076):
/// `-rw-r--r--  0 501  0  12 Nov  9 17:13 name`, with `Jan  2  2020` for an
/// entry more than half a year from now.
extension ArchiveEntry {
    private static let months = [
        "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4, "May": 5, "Jun": 6, "Jul": 7, "Aug": 8, "Sep": 9,
        "Oct": 10, "Nov": 11, "Dec": 12,
    ]
    private static let fieldsFromSizeToTime = 4
    private static let yearDigits = 4
    private static let octalDigits = 3
    private static let octalBase: UInt8 = 8
    private static let zero = UInt8(ascii: "0")
    private static let seven = UInt8(ascii: "7")
    private static let backslash = UInt8(ascii: "\\")
    private static let escapes: [UInt8: UInt8] = [
        UInt8(ascii: "n"): 10, UInt8(ascii: "t"): 9, UInt8(ascii: "r"): 13, UInt8(ascii: "a"): 7,
        UInt8(ascii: "b"): 8, UInt8(ascii: "f"): 12, UInt8(ascii: "v"): 11, backslash: backslash,
    ]

    /// Reads a listing's line, or returns `nil` for a line that is no entry.
    /// An owner's name may hold spaces, so the size is found by the date after it.
    ///
    /// - Parameters:
    ///   - now: a listed time has no year; it is the one nearest to `now`.
    ///   - calendar: the calendar and time zone the listing is in.
    public init?(listingLine line: String, now: Date, calendar: Calendar) {
        let fields = line.split(separator: " ")
        guard let mode = fields.first?.first,
            fields.count > Self.fieldsFromSizeToTime,
            let sizeIndex = (1..<(fields.count - Self.fieldsFromSizeToTime + 1)).first(where: {
                Self.isSizeAndDate(fields, at: $0)
            }),
            let size = Int64(fields[sizeIndex]),
            let last = fields[sizeIndex + Self.fieldsFromSizeToTime - 1].indices.last,
            let start = line.index(last, offsetBy: 2, limitedBy: line.endIndex),
            start < line.endIndex
        else { return nil }
        let date = Self.date(
            month: fields[sizeIndex + 1], day: fields[sizeIndex + 2],
            timeOrYear: fields[sizeIndex + Self.fieldsFromSizeToTime - 1], now: now,
            calendar: calendar)
        self.init(
            storedName: Self.unescaped(Self.nameWithoutTarget(line[start...], mode: mode)),
            isFolder: mode == "d", size: size, modified: date.value,
            modifiedHasTime: date.hasTime)
    }

    private static func isSizeAndDate(_ fields: [Substring], at index: Int) -> Bool {
        guard fields[index].allSatisfy(\.isNumber), months[String(fields[index + 1])] != nil,
            fields[index + 2].allSatisfy(\.isNumber)
        else { return false }
        let last = fields[index + fieldsFromSizeToTime - 1]
        return last.contains(":") || (last.count == yearDigits && last.allSatisfy(\.isNumber))
    }

    private static func date(
        month: Substring, day: Substring, timeOrYear: Substring, now: Date, calendar: Calendar
    ) -> (value: Date?, hasTime: Bool) {
        var parts = DateComponents(month: months[String(month)], day: Int(day))
        guard timeOrYear.contains(":") else {
            parts.year = Int(timeOrYear)
            return (calendar.date(from: parts), false)
        }
        let time = timeOrYear.split(separator: ":")
        parts.hour = time.first.flatMap { Int($0) }
        parts.minute = time.last.flatMap { Int($0) }
        let year = calendar.component(.year, from: now)
        let nearest = [year - 1, year, year + 1].compactMap { candidate -> Date? in
            parts.year = candidate
            return calendar.date(from: parts)
        }
        .min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) }
        return (nearest, true)
    }

    private static func nameWithoutTarget(_ text: Substring, mode: Character) -> Substring {
        let marker = mode == "l" ? " -> " : mode == "h" ? " link to " : nil
        guard let marker, let range = text.firstRange(of: marker) else { return text }
        return text[..<range.lowerBound]
    }

    /// Undoes the escapes `tar` writes for what it cannot print: `\n`, `\\`,
    /// and `\303` for a byte.
    private static func unescaped(_ text: Substring) -> String {
        let bytes = Array(text.utf8)
        var result: [UInt8] = []
        var index = 0
        while index < bytes.count {
            guard bytes[index] == backslash, index + 1 < bytes.count else {
                result.append(bytes[index])
                index += 1
                continue
            }
            if let byte = octal(bytes, at: index + 1) {
                result.append(byte)
                index += octalDigits + 1
            } else if let byte = escapes[bytes[index + 1]] {
                result.append(byte)
                index += 2
            } else {
                result.append(bytes[index])
                index += 1
            }
        }
        return String(bytes: result, encoding: .utf8) ?? String(text)
    }

    private static func octal(_ bytes: [UInt8], at index: Int) -> UInt8? {
        guard index + octalDigits <= bytes.count else { return nil }
        var value: UInt8 = 0
        for digit in bytes[index..<(index + octalDigits)] {
            guard (zero...seven).contains(digit) else { return nil }
            let (shifted, overflow) = value.multipliedReportingOverflow(by: octalBase)
            guard !overflow else { return nil }
            value = shifted + (digit - zero)
        }
        return value
    }
}
