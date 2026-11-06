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
        guard let cycle = counterCycle(in: parts) else {
            return Period(year: fileYear, seq: nil, usesFileYear: fileYear != nil)
        }
        let steps = context.siblingNames.compactMap { step(in: $0, parts: parts, fixed: fixed) }
        guard let last = steps.max(by: { ($0.year ?? 0, $0.seq) < ($1.year ?? 0, $1.seq) }) else {
            let width = cycle.map { String($0).count } ?? 1
            return Period(year: fileYear, seq: padded(1, to: width), usesFileYear: fileYear != nil)
        }
        var seq = last.seq + 1
        var year = last.year
        if let limit = cycle, seq > limit {
            seq = 1
            year = year.map { $0 + 1 }
        }
        guard hasYear else { return Period(year: nil, seq: padded(seq, to: last.width)) }
        return Period(
            year: year ?? fileYear, seq: padded(seq, to: last.width),
            usesFileYear: year == nil && fileYear != nil)
    }

    /// The cycle of the first `{seq}`: `.some(nil)` when it keeps counting, nil without one.
    private static func counterCycle(in parts: [Part]) -> Int?? {
        for part in parts {
            switch part {
            case .counter(let cycle):
                return .some(cycle)
            case .optional(let inner), .choice(let inner):
                if let found = counterCycle(in: inner) { return found }
            case .alternatives(let all):
                if let found = all.lazy.compactMap(counterCycle(in:)).first { return found }
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
        let year = Range(match.range(withName: yearGroup), in: name).flatMap { Int(name[$0]) }
        return Step(year: year, seq: seq, width: name[seqRange].count)
    }

    private static func padded(_ number: Int, to width: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
