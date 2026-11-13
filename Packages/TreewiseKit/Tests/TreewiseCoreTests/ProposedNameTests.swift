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

    @Test func rejectsAColon() {
        #expect(resolve("a:b") == .failure(.containsPathSeparator))
    }

    @Test func allowsASlashAsFinderDoes() {
        #expect(resolve("JK/o/26049") == .success("JK/o/26049.pdf"))
    }

    @Test func storesASlashAsAColon() {
        #expect(ProposedName.diskName(fromShown: "JK/o/26049.pdf") == "JK:o:26049.pdf")
    }

    @Test func showsAColonAsASlash() {
        #expect(ProposedName.shownName(fromDisk: "JK:o:26049.pdf") == "JK/o/26049.pdf")
    }

    @Test(arguments: [
        ("a  b.pdf", "a b.pdf"), (" a.pdf", "a.pdf"), ("a .pdf", "a.pdf"),
        ("a   b  c.pdf", "a b c.pdf"),
    ])
    func repairsStraySpaces(_ name: String, _ repaired: String) {
        #expect(ProposedName.repairingSpaces(in: name) == repaired)
    }

    @Test func repairsSpacesInANameWithoutExtension() {
        #expect(
            ProposedName.repairingSpaces(in: "2026.04.28 Permit  request")
                == "2026.04.28 Permit request")
    }

    @Test(arguments: [
        ("a.pdf", "a"), ("2026.04.28 Permit request", "2026.04.28 Permit request"),
        ("Payroll 2026.09", "Payroll 2026.09"), ("Payroll 2026.09.pdf", "Payroll 2026.09"),
        ("a.tar.gz", "a"), (".hidden", ".hidden"),
    ])
    func findsTheStemOfAName(_ name: String, _ stem: String) {
        #expect(ProposedName.stem(of: name) == stem)
    }

    @Test func leavesCleanSpacesAlone() {
        #expect(ProposedName.repairingSpaces(in: "a b.pdf") == nil)
    }

    @Test func leavesAGapToBeFilledIn() {
        #expect(resolve("a - " + NameTemplate.gap) == .success("a - " + NameTemplate.gap + ".pdf"))
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
        #expect(ProposedName.problem(inEdit: "a:b") == .containsPathSeparator)
        #expect(ProposedName.problem(inEdit: "a/b") == nil)
    }

    @Test func makesProposalsFromRankedValues() throws {
        let fields = [NameTemplate.Field(name: "number", kind: .number), .folder]
        let template = try NameTemplate.parse("{folder} {number}", fields: fields).get()
        let proposals = NameProposal.make(
            from: [["number": .text("1")], [:], ["number": .text("2")]], template: template,
            moduleID: "m", folderName: "Invoices", suggestedDate: nil)
        #expect(
            proposals == [
                NameProposal(name: "Invoices 1", moduleID: "m", dateSource: nil),
                NameProposal(name: "Invoices 2", moduleID: "m", dateSource: nil),
            ])
    }

    @Test func aModuleCannotChooseTheFolderName() throws {
        let template = try NameTemplate.parse("{folder}", fields: [.folder]).get()
        let proposals = NameProposal.make(
            from: [["folder": .text("Other")]], template: template, moduleID: "m",
            folderName: "Invoices", suggestedDate: nil)
        #expect(proposals.first?.name == "Invoices")
    }

    /// `{folder:2}` is the folder above the item's folder (ADR 0089).
    @Test func namesTheFoldersAboveTheItem() throws {
        let fields = [NameTemplate.Field(name: "number", kind: .number), .folder]
        let template = try NameTemplate.parse("{folder:2} {folder} {number}", fields: fields).get()
        let proposals = NameProposal.make(
            from: [["number": .text("1")]], template: template, moduleID: "m",
            folderName: "2026", foldersAbove: ["Acme", "Clients"], suggestedDate: nil)
        #expect(proposals.first?.name == "Acme 2026 1")
    }

    @Test func aDateFromTheFileKeepsItsSource() throws {
        let fields = [NameTemplate.Field(name: "date", kind: .date)]
        let template = try NameTemplate.parse("{date}", fields: fields).get()
        let date = SuggestedDate(year: 2026, month: 11, day: 2, source: .insideFile)
        let fromFile = NameProposal.make(
            from: [["date": date.value]], template: template, moduleID: "m", folderName: "",
            suggestedDate: date)
        #expect(fromFile.first?.dateSource == .insideFile)
    }

    @Test func aDateAModuleFoundHasNoSuchSource() throws {
        let fields = [NameTemplate.Field(name: "date", kind: .date)]
        let template = try NameTemplate.parse("{date}", fields: fields).get()
        let date = SuggestedDate(year: 2026, month: 11, day: 2, source: .fileSystem)
        let found = NameProposal.make(
            from: [["date": .date(year: 2026, month: 1, day: 1)]], template: template,
            moduleID: "m",
            folderName: "", suggestedDate: date)
        #expect(found.first?.dateSource == nil)
    }

    @Test func aTemplateWithoutADateHasNoDateSource() throws {
        let fields = [
            NameTemplate.Field(name: "date", kind: .date),
            NameTemplate.Field(name: "text", kind: .text),
        ]
        let template = try NameTemplate.parse("{text}", fields: fields).get()
        let date = SuggestedDate(year: 2026, month: 11, day: 2, source: .fileSystem)
        let made = NameProposal.make(
            from: [["date": date.value, "text": .text("a")]], template: template, moduleID: "m",
            folderName: "", suggestedDate: date)
        #expect(made.first?.dateSource == nil)
    }
}

/// A name that nearly fits is offered written right, first (ADR 0067).
@Suite struct NameProposalNearlyFittingTests {
    private static let fields = [
        NameTemplate.Field(name: "date", kind: .date),
        NameTemplate.Field(name: "text", kind: .text),
    ]

    private func proposals(values: [[String: NameTemplate.Value]]) throws -> [String] {
        let template = try NameTemplate.parse(
            "{date:yyyy.MM.dd} - {folder} - {text}",
            fields: Self.fields + NameTemplate.Field.suppliedByTreewise
        ).get()
        return NameProposal.make(
            from: values, template: template, moduleID: "m", folderName: "Holiday 2026",
            suggestedDate: nil, currentName: "2026.08.14 - Holiday 202 - c.heic"
        ).map(\.name)
    }

    @Test func offersTheNameWrittenRightFirst() throws {
        let values: [[String: NameTemplate.Value]] = [
            ["date": .date(year: 2026, month: 8, day: 14), "text": .text("Beach")]
        ]
        #expect(
            try proposals(values: values) == [
                "2026.08.14 - Holiday 2026 - c", "2026.08.14 - Holiday 2026 - Beach",
            ])
    }

    @Test func offersTheSameNameOnce() throws {
        let values: [[String: NameTemplate.Value]] = [
            ["date": .date(year: 2026, month: 8, day: 14), "text": .text("c")]
        ]
        #expect(try proposals(values: values) == ["2026.08.14 - Holiday 2026 - c"])
    }

    @Test func offersItWithoutValuesToo() throws {
        #expect(try proposals(values: []) == ["2026.08.14 - Holiday 2026 - c"])
    }
}
