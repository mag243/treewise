import Foundation
import Testing
import TreewiseCore

/// What a proposed or edited name must be before it can reach a file (ADR 0057).
@Suite struct ProposedNameTests {
    private func resolve(
        _ name: String, for original: String = "scan.pdf", kind: ItemKind = .file,
        replacesExtension: Bool = false
    ) -> Result<String, ProposedNameProblem> {
        let proposal = NameProposal(
            name: name, moduleID: "test", confidence: 1, replacesExtension: replacesExtension)
        return ProposedName.resolve(proposal, for: original, kind: kind)
    }

    @Test func addsTheOriginalExtension() {
        #expect(resolve("Invoice 12") == .success("Invoice 12.pdf"))
    }

    @Test func doesNotDoubleAnExtensionThatIsAlreadyThere() {
        #expect(resolve("Invoice 12.PDF") == .success("Invoice 12.PDF"))
    }

    @Test func keepsDotsInsideTheName() {
        #expect(resolve("2026.11.02 Invoice") == .success("2026.11.02 Invoice.pdf"))
    }

    @Test func keepsACompoundExtensionWhole() {
        #expect(resolve("Backup", for: "old.tar.gz") == .success("Backup.tar.gz"))
    }

    @Test func replacesTheExtensionOnlyWhenTheProposalSaysSo() {
        #expect(resolve("Invoice.txt", replacesExtension: true) == .success("Invoice.txt"))
        #expect(resolve("Invoice.txt") == .success("Invoice.txt.pdf"))
    }

    @Test func addsNoExtensionToAFolder() {
        #expect(resolve("Invoices", for: "v1.2", kind: .folder) == .success("Invoices"))
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(resolve("  Invoice \n") == .success("Invoice.pdf"))
    }

    @Test(arguments: ["", "   ", "\n"])
    func rejectsAnEmptyName(_ name: String) {
        #expect(resolve(name) == .failure(.empty))
    }

    @Test(arguments: ["a/b", "../b", "a:b"])
    func rejectsPathSeparators(_ name: String) {
        #expect(resolve(name) == .failure(.containsPathSeparator))
    }

    @Test(arguments: ["a\u{0}b", "a\nb", "a\u{7F}b"])
    func rejectsControlCharacters(_ name: String) {
        #expect(resolve(name) == .failure(.containsControlCharacter))
    }

    @Test(arguments: [".hidden", ".pdf", "..", "."])
    func rejectsAProposalThatWouldHideTheFile(_ name: String) {
        #expect(resolve(name) == .failure(.startsWithDot))
    }

    @Test func rejectsANameTooLongOnceItHasItsExtension() {
        let longest = String(repeating: "a", count: ProposedName.maximumByteCount - ".pdf".count)
        #expect(resolve(longest) == .success(longest + ".pdf"))
        #expect(resolve(longest + "a") == .failure(.tooLong))
    }

    @Test func countsBytesAndNotCharacters() {
        let name = String(repeating: "é", count: ProposedName.maximumByteCount / 2)
        #expect(resolve(name) == .failure(.tooLong))
    }

    @Test func allowsAnEditThatStartsWithADot() {
        #expect(ProposedName.problem(inEdit: ".config") == nil)
    }

    @Test func checksAnEditAsItIsTyped() {
        #expect(ProposedName.problem(inEdit: " ") == .empty)
        #expect(ProposedName.problem(inEdit: "a/b") == .containsPathSeparator)
    }

    @Test(arguments: [(Double.nan, 0.0), (-1, 0), (2, 1), (0.5, 0.5)])
    func keepsConfidenceBetweenZeroAndOne(_ given: Double, _ expected: Double) {
        #expect(NameProposal(name: "a", moduleID: "m", confidence: given).confidence == expected)
    }

    @Test func decodingAProposalKeepsConfidenceInRangeToo() throws {
        let json = #"{"name":"a","moduleID":"m","confidence":7,"replacesExtension":false}"#
        let proposal = try JSONDecoder().decode(NameProposal.self, from: Data(json.utf8))
        #expect(proposal.confidence == 1)
    }

    @Test func aProposalSurvivesEncoding() throws {
        let proposal = NameProposal(
            name: "a", moduleID: "m", confidence: 0.5, replacesExtension: true)
        let decoded = try JSONDecoder().decode(
            NameProposal.self, from: JSONEncoder().encode(proposal))
        #expect(decoded == proposal)
    }
}
