import Testing

@testable import TreewiseCore

/// The fields in a template's folder names (ADR 0096): `{year}`, `{year:yy}`, `{text}`,
/// `{seq}` and `{date}`, written as in name patterns, and plain text for anything else.
@Suite struct FolderTemplateFieldsTests {
    private static let client = FolderTree(
        name: "P-{seq:0001-} {text:title}",
        folders: [FolderTree(name: "Contract"), FolderTree(name: "Summary {year}")])

    private static func values(
        year: Int? = nil, text: String? = nil, number: Int? = nil,
        date: FolderTemplateValues.Day? = nil
    ) -> FolderTemplateValues {
        FolderTemplateValues(
            year: year, text: text, number: number.map { .init(value: $0, width: 4) },
            date: date, language: .english)
    }

    @Test func listsItsFieldsInTheOrderTheyFirstAppearFromTheRootDown() {
        #expect(Self.client.fields == [.number, .text, .year])
    }

    @Test func aYearInTwoDigitsIsAYear() {
        let tree = FolderTree(name: "Tax {year:yy}")
        #expect(tree.hasYear)
        #expect(tree.filling(year: 2027).name == "Tax 27")
    }

    @Test func fillsEachFieldInItsFormat() {
        let filled = Self.client.filling(Self.values(year: 2027, text: "acme bv", number: 143))
        #expect(filled.name == "P-0143 Acme Bv")
        #expect(filled.folders.map(\.name) == ["Contract", "Summary 2027"])
    }

    @Test func writesADateInTheTemplatesFormatAndLanguage() {
        let day = FolderTemplateValues.Day(year: 2026, month: 11, day: 14)
        let iso = FolderTree(name: "{date} Shoot")
        let month = FolderTree(name: "{date:MMMM yyyy}")
        #expect(iso.filling(Self.values(date: day)).name == "2026-11-14 Shoot")
        #expect(month.filling(Self.values(date: day)).name == "November 2026")
        let dutch = FolderTemplateValues(
            year: nil, text: nil, number: nil, date: day, language: .dutch)
        #expect(month.filling(dutch).name == "november 2026")
    }

    @Test func writesOneTextInTheCaseOfEachPlace() {
        let tree = FolderTree(name: "{text}", folders: [FolderTree(name: "{text:upper} Notes")])
        let filled = tree.filling(Self.values(text: "acme"))
        #expect(filled.name == "acme")
        #expect(filled.folders.map(\.name) == ["ACME Notes"])
    }

    @Test func leavesAFieldWithoutAValueAsWritten() {
        #expect(Self.client.filling(year: 2027).name == "P-{seq:0001-} {text:title}")
    }

    @Test(arguments: ["{draft}", "Archive [old]", "A | B", "<Inbox>", "{}", "{year"])
    func keepsBracesThatHoldNoFieldAsPlainText(name: String) throws {
        let tree = FolderTree(name: "Root", folders: [FolderTree(name: name)])
        try tree.checkTemplate()
        #expect(tree.filling(Self.values(year: 2027, text: "x")).folders.map(\.name) == [name])
        #expect(tree.fields.isEmpty)
    }

    @Test(arguments: ["{date:qq}", "{year:yyyy}", "{text:shout}", "{seq:4-2}"])
    func refusesAFieldWithAFormatItDoesNotTake(name: String) {
        #expect(throws: FolderTree.Problem.invalidFormat(name)) {
            try FolderTree(name: name).checkTemplate()
        }
    }

    @Test func refusesANumberBelowTheTopFolder() {
        let tree = FolderTree(name: "Project", folders: [FolderTree(name: "{seq} Intake")])
        #expect(throws: FolderTree.Problem.numberBelowTop("{seq} Intake")) {
            try tree.checkTemplate()
        }
    }

    @Test func takesAColonInsideAFieldButNotInItsPlainText() throws {
        try FolderTree(name: "{date:yyyy-MM-dd} Shoot").checkTemplate()
        #expect(throws: FolderTree.Problem.invalidName("a:b {year}")) {
            try FolderTree(name: "a:b {year}").checkTemplate()
        }
    }

    @Test func fillsAFolderThatIsThereUnderItsOwnName() {
        let filled = Self.client.filling(folderNamed: "Acme")
        #expect(filled.name == "Acme")
        #expect(filled.folders.map(\.name) == ["Contract", "Summary {year}"])
        #expect(Self.client.fieldsBelowRoot == [.year])
    }

    @Test func aTemplateRootedAtTheYearFillsAYearsFolderItself() {
        let year = FolderTemplate(name: "Year", root: FolderTree(name: "{year}"))
        #expect(year.yearOfFolderItFills(named: "2027") == 2027)
        #expect(year.yearOfFolderItFills(named: "Tax") == nil)
        let client = FolderTemplate(name: "Client", root: Self.client)
        #expect(client.yearOfFolderItFills(named: "2027") == nil)
    }

    @Test func checksATemplateAsATreeOtherwise() {
        let tree = FolderTree(name: "{year}", folders: [FolderTree(name: ".hidden")])
        #expect(throws: FolderTree.Problem.hiddenName(".hidden")) { try tree.checkTemplate() }
    }
}
