import Testing
import TreewiseCore
import TreewiseUI

/// The stretch of a proposed name the review colours for a look: its gap, else the date
/// that came from the file (ADR 0058).
@Suite struct NameReviewLookTests {
    private func marked(_ name: String, dateFromFile: Bool = true) -> String? {
        NameReviewLook.mark(in: name, dateFromFile: dateFromFile).map { String(name[$0.range]) }
    }

    @Test func marksTheGap() {
        let name = "Invoice \(NameTemplate.gap) 2026-03-14"
        #expect(marked(name) == NameTemplate.gap)
        #expect(NameReviewLook.mark(in: name, dateFromFile: true)?.kind == .gap)
    }

    @Test(arguments: ["2026-03-14", "14.03.2026", "20260314"])
    func marksADateFromTheFile(_ date: String) {
        #expect(marked("Invoice \(date) Acme") == date)
        #expect(
            NameReviewLook.mark(in: "Invoice \(date)", dateFromFile: true)?.kind == .dateToCheck)
    }

    @Test func marksNothingInANameWithoutADate() {
        #expect(marked("Invoice Acme") == nil)
    }

    @Test func marksNoDateThatDidNotComeFromTheFile() {
        #expect(marked("Invoice 2026-03-14", dateFromFile: false) == nil)
    }
}
