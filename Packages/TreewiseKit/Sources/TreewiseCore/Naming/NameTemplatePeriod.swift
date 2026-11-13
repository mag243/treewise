import Foundation

/// The next period of a series, for `{year}` and `{seq}` (ADR 0064).
extension NameTemplate {
    /// What `{year}` and `{seq}` are in a name to be made.
    struct Period: Hashable, Sendable {
        var year: Int?
        var seq: String?
        var usesFileYear = false
    }

    /// One name of a series, as read back.
    private struct Step {
        let year: Int?
        let seq: Int
        let width: Int
    }

    /// The period after the highest in the names that fit `parts`. Without a sequence,
    /// `{year}` is the year of the file's date; a series without names starts at 1.
    static func nextPeriod(for parts: [Part], context: Context, fixed: [String: String]) -> Period {
        let fields = fields(in: parts)
        let hasYear = fields.contains { $0.kind == .year }
        let fileYear = hasYear ? context.fileYear : nil
        guard let series = counterSeries(in: parts) else {
            return Period(year: fileYear, seq: nil, usesFileYear: fileYear != nil)
        }
        // Only names that fit count, so a number the series cannot give starts nothing.
        let steps = context.siblingNames.compactMap { step(in: $0, parts: parts, fixed: fixed) }
        guard let last = steps.max(by: { ($0.year ?? 0, $0.seq) < ($1.year ?? 0, $1.seq) }) else {
            return Period(
                year: fileYear, seq: padded(series.first, to: series.width),
                usesFileYear: fileYear != nil)
        }
        let following = series.number(after: last.seq)
        let seq = following ?? series.first
        // After its last number a series starts again, in the next year.
        let year = following == nil ? last.year.map { $0 + 1 } : last.year
        // A width written in the pattern wins over that of the names there (ADR 0089).
        let width = series.writtenWidth ?? last.width
        guard hasYear else { return Period(year: nil, seq: padded(seq, to: width)) }
        return Period(
            year: year ?? fileYear, seq: padded(seq, to: width),
            usesFileYear: year == nil && fileYear != nil)
    }

    /// The series of the first `{seq}`, or nil without one.
    private static func counterSeries(in parts: [Part]) -> Series? {
        for part in parts {
            switch part {
            case .counter(let series):
                return series
            case .optional(let inner), .choice(let inner):
                if let found = counterSeries(in: inner) { return found }
            case .alternatives(let all):
                if let found = all.lazy.compactMap(counterSeries(in:)).first { return found }
            case .text, .field:
                continue
            }
        }
        return nil
    }

    private static func step(in name: String, parts: [Part], fixed: [String: String]) -> Step? {
        guard let match = match(name, parts, fixed: fixed),
            let seqRange = Range(match.range(withName: seqGroup), in: name),
            let seq = Int(name[seqRange])
        else { return nil }
        let year = Range(match.range(withName: yearGroup), in: name).flatMap { range in
            // A year in two digits is one of this century (ADR 0089).
            Int(name[range]).map { name[range].count == 2 ? 2000 + $0 : $0 }
        }
        return Step(year: year, seq: seq, width: name[seqRange].count)
    }

    private static func padded(_ number: Int, to width: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
