import Testing
import TreewiseCore

/// Whether dates inside a folder's files can go without a look (ADR 0057).
@Suite struct DateReliabilityTests {
    private func samples(same: Int, different: Int) -> [DateReliability.Sample] {
        let date = NameTemplate.Value.date(year: 2026, month: 1, day: 1)
        let other = NameTemplate.Value.date(year: 2026, month: 2, day: 2)
        return Array(repeating: .init(inName: date, insideFile: date), count: same)
            + Array(repeating: .init(inName: other, insideFile: date), count: different)
    }

    @Test(arguments: [
        (5, 0, true), (4, 0, false), (9, 1, true), (8, 1, false), (14, 0, true), (13, 4, false),
    ])
    func needsEnoughFilesThatAgree(_ same: Int, _ different: Int, _ reliable: Bool) {
        #expect(DateReliability.isReliable(samples(same: same, different: different)) == reliable)
    }

    @Test func noFilesProveNothing() {
        #expect(!DateReliability.isReliable([]))
    }
}
