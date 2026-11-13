import Foundation

extension NameTemplate {
    /// The numbers a `{seq}` gives (ADR 0064, ADR 0089): a range, with or without an end, or a
    /// rising list.
    ///
    /// Invariant: a range has a first number of 0 or more and, when it ends, a last one above
    /// it; a list holds two or more numbers of 0 or more, rising.
    struct Series: Hashable, Sendable {
        enum Numbers: Hashable, Sendable {
            case range(first: Int, last: Int?)
            case list([Int])
        }

        let numbers: Numbers
        /// The least number of digits written for the series: by leading zeros, as in
        /// `001-`, or after a second colon, as in `5-:3`; nil when none is written.
        let writtenWidth: Int?

        /// `{seq}` without anything after its colon: 1, 2, 3, … without end.
        static let counting = Series(numbers: .range(first: 1, last: nil), writtenWidth: nil)

        /// The series written after `{seq:`, as `4`, `2-4`, `5-` or `2,4,6,8`, each with
        /// leading zeros for a width or followed by `:` and one, as `5-:3` or `:3`; nil when
        /// the text is no series (ADR 0089).
        init?(_ text: String) {
            let pieces = text.split(separator: ":", omittingEmptySubsequences: false)
            guard pieces.count <= 2 else { return nil }
            var width: Int?
            if pieces.count == 2 {
                guard let written = Self.number(pieces[1]), written >= 1 else { return nil }
                width = written
            }
            let series = String(pieces[0])
            if series.isEmpty, width != nil {
                numbers = Self.counting.numbers
            } else {
                guard let read = Self.numbers(series) else { return nil }
                numbers = read
            }
            writtenWidth = width ?? Self.widthOfLeadingZeros(in: series)
        }

        private init(numbers: Numbers, writtenWidth: Int?) {
            self.numbers = numbers
            self.writtenWidth = writtenWidth
        }

        /// The length of the longest number written with a leading zero, or nil when none is.
        private static func widthOfLeadingZeros(in text: String) -> Int? {
            let written = text.split(whereSeparator: { $0 == "," || $0 == "-" })
            guard written.contains(where: { $0.count > 1 && $0.first == "0" }) else { return nil }
            return written.map(\.count).max()
        }

        private static func numbers(_ text: String) -> Numbers? {
            if text.contains(",") {
                let parts = text.split(separator: ",", omittingEmptySubsequences: false)
                let list = parts.compactMap { Self.number($0) }
                guard list.count == parts.count, list.count >= 2,
                    zip(list, list.dropFirst()).allSatisfy({ $0 < $1 })
                else { return nil }
                return .list(list)
            }
            if text.contains("-") {
                let parts = text.split(separator: "-", omittingEmptySubsequences: false)
                guard parts.count == 2, let first = Self.number(parts[0]) else { return nil }
                if parts[1].isEmpty { return .range(first: first, last: nil) }
                guard let last = Self.number(parts[1]), last > first else { return nil }
                return .range(first: first, last: last)
            }
            guard let last = Self.number(Substring(text)), last >= 2 else { return nil }
            return .range(first: 1, last: last)
        }

        private static func number(_ text: Substring) -> Int? {
            guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int(text)
        }

        /// The number a series without names starts at.
        var first: Int {
            switch numbers {
            case .range(let first, _): first
            case .list(let list): list[0]
            }
        }

        /// The width its numbers are written in: the width written, else that of its
        /// highest, or 1 without an end.
        var width: Int {
            if let writtenWidth { return writtenWidth }
            return switch numbers {
            case .range(_, let last?): String(last).count
            case .range: 1
            case .list(let list): String(list[list.count - 1]).count
            }
        }

        /// The number after `number`, or nil when the series starts again after it.
        func number(after number: Int) -> Int? {
            switch numbers {
            case .range(_, let last): last.map { number < $0 ? number + 1 : nil } ?? number + 1
            case .list(let list): list.first { $0 > number }
            }
        }

        /// A regular expression that fits a number of the series, with leading zeros or
        /// without, and no other number.
        var pattern: String {
            let alternatives: [String]
            switch numbers {
            case .list(let list):
                alternatives = list.map(String.init)
            case .range(let first, let last?):
                alternatives = NumberRange.patterns(from: first, to: last)
            case .range(let first, nil):
                let digits = String(first).count
                let longer = "[1-9][0-9]{\(digits),}"
                alternatives =
                    NumberRange.patterns(from: first, to: NumberRange.highest(withDigits: digits))
                    + [longer]
            }
            return "0*(?:" + alternatives.joined(separator: "|") + ")"
        }
    }
}

/// Regular expressions for the whole numbers in a range, written without leading zeros.
enum NumberRange {
    /// The highest number with this many digits.
    static func highest(withDigits digits: Int) -> Int {
        Int(String(repeating: "9", count: digits)) ?? Int.max
    }

    /// Patterns that together fit every number from `low` to `high` and no other.
    /// - Precondition: `0 <= low <= high`.
    static func patterns(from low: Int, to high: Int) -> [String] {
        precondition(0 <= low && low <= high, "A range runs from 0 or more up to its end.")
        var patterns: [String] = []
        var digits = String(low).count
        var start = low
        while start <= high {
            let end = min(high, highest(withDigits: digits))
            patterns += sameLength(from: start, to: end, digits: digits)
            start = end + 1
            digits += 1
        }
        return patterns
    }

    /// Patterns for numbers of one length: each a fixed beginning, one digit in a span,
    /// and any digits after it.
    private static func sameLength(from low: Int, to high: Int, digits: Int) -> [String] {
        var patterns: [String] = []
        var start = low
        // A block never takes the first digit, so every number keeps its length.
        let largestStep = Int(pow(10, Double(digits - 1)))
        while start <= high {
            var step = 1
            while step < largestStep, start % (step * 10) == 0, start + step * 10 - 1 <= high {
                step *= 10
            }
            let decadeEnd = (start / (step * 10) + 1) * step * 10 - 1
            let blockEnd = min(high, decadeEnd)
            let end = start + ((blockEnd - start + 1) / step) * step - 1
            patterns.append(pattern(from: start, to: end, step: step))
            start = end + 1
        }
        return patterns
    }

    private static func pattern(from low: Int, to high: Int, step: Int) -> String {
        let head = String(low / step)
        let last = String(high / step).last ?? "9"
        let free = String(step).count - 1
        let span = head.last == last ? String(last) : "[\(head.last ?? "0")-\(last)]"
        return String(head.dropLast()) + span + (free > 0 ? "[0-9]{\(free)}" : "")
    }
}
