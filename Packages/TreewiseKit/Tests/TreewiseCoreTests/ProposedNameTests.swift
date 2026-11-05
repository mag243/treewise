import Testing
import TreewiseCore

/// What a proposed or edited name must be before it can reach a file (ADR 0057).
@Suite struct ProposedNameTests {
    private func resolve(
        _ name: String, for original: String = "scan.pdf", kind: ItemKind = .file
    ) -> Result<String, ProposedNameProblem> {
        let proposal = NameProposal(name: name, moduleID: "test")
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

    @Test func makesProposalsFromRankedValues() throws {
        let fields = [NameTemplate.Field(name: "number", kind: .number), .folder]
        let template = try NameTemplate.parse("{folder} {number}", fields: fields).get()
        let proposals = NameProposal.make(
            from: [["number": .text("1")], [:], ["number": .text("2")]], template: template,
            moduleID: "m", folderName: "Invoices")
        #expect(
            proposals == [
                NameProposal(name: "Invoices 1", moduleID: "m"),
                NameProposal(name: "Invoices 2", moduleID: "m"),
            ])
    }

    @Test func aModuleCannotChooseTheFolderName() throws {
        let template = try NameTemplate.parse("{folder}", fields: [.folder]).get()
        let proposals = NameProposal.make(
            from: [["folder": .text("Other")]], template: template, moduleID: "m",
            folderName: "Invoices")
        #expect(proposals.first?.name == "Invoices")
    }
}
