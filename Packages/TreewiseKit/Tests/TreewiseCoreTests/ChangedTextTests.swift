import Testing
import TreewiseCore

/// The part of a name that changed, to select it when the user steps to another option
/// (ADR 0064).
@Suite struct ChangedTextTests {
    private func changed(_ old: String, _ new: String) -> String {
        String(new[ChangedText.range(from: old, to: new)])
    }

    @Test func findsWhatLiesBetweenTheSameStartAndEnd() {
        #expect(changed("Tax - Sales 2026.Q1.pdf", "Tax - Payroll 2026.01.pdf") == "Payroll 2026.0")
    }

    @Test func findsAnInsertedPart() {
        #expect(changed("Invoice.pdf", "Invoice F26009.pdf") == " F26009")
    }

    @Test func findsNothingInTheSameName() {
        let name = "Invoice.pdf"
        let range = ChangedText.range(from: name, to: name)
        #expect(range.isEmpty)
    }

    @Test func doesNotCountACharacterTwice() {
        // `aa` shares both its start and its end with `aaa`; the third is what was added.
        #expect(changed("aa", "aaa") == "a")
    }
}
