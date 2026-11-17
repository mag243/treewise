import Testing
import TreewiseCore
import TreewiseUI

/// The coloured stretches of a pattern and a name, the same on the Mac and the iPad
/// (ADR 0064, 0130).
@Suite struct NameMarkTests {
    private func coloured(_ marks: [NameMark], in text: String) -> [String] {
        marks.map { String(text[$0.range]) }
    }

    @Test func colorsEachFieldOfAPatternByItsFirstPlace() {
        let pattern = "{date} {title} {date}"

        let marks = NameMark.inPattern(pattern)

        #expect(coloured(marks, in: pattern) == ["{date}", "{title}", "{date}"])
        #expect(marks.map(\.tint) == [.field(0), .field(1), .field(0)])
    }

    @Test func colorsAGapInAName() {
        let name = "2026-11-17 \(NameTemplate.gap).pdf"

        let marks = NameMark.look(in: name, dateFromFile: false)

        #expect(coloured(marks, in: name) == [NameTemplate.gap])
        #expect(marks.map(\.tint) == [.gap])
    }

    @Test func colorsADateFromTheFileToCheck() {
        let name = "2026-11-17 Receipt.pdf"

        #expect(NameMark.look(in: name, dateFromFile: true).map(\.tint) == [.dateToCheck])
        #expect(NameMark.look(in: name, dateFromFile: false).isEmpty)
    }

    @Test func theFieldsTakeTheHuesInTurn() {
        let count = NameColors.fieldHues.count

        #expect(NameColors.fieldHue(0) == .treewiseYellow)
        #expect(NameColors.fieldHue(count) == NameColors.fieldHue(0))
    }
}
