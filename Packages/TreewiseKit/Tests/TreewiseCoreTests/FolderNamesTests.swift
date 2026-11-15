import Testing
import TreewiseCore

/// The names around a file, split once for the whole folder.
@Suite struct FolderNamesTests {
    @Test func givesTheStemsOfTheOtherNames() {
        let names = FolderNames(["Invoice 1.pdf", "Invoice 2.pdf", "archive.tar.gz", "Notes"])
        #expect(names.stems(besides: "Invoice 2.pdf") == ["Invoice 1", "archive", "Notes"])
    }

    @Test func givesEveryStemForANameNotInTheFolder() {
        #expect(FolderNames(["a.md", "b.md"]).stems(besides: "c.md") == ["a", "b"])
    }

    @Test func proposesTheNextNumberWithoutTheItemsOwnName() throws {
        let template = try NameTemplate.parse(
            "Invoice {seq}", fields: NameTemplate.Field.suppliedByTreewise
        ).get()
        let names = FolderNames(["Invoice 07.pdf", "Invoice 08.pdf", "Scan.pdf"])
        let proposals = { (current: String) in
            NameProposal.make(
                from: [[:]], template: template, moduleID: "m", folderName: "Invoices",
                suggestedDate: nil, folderNames: names, currentName: current
            ).map(\.name)
        }
        #expect(proposals("Scan.pdf") == ["Invoice 09"])
        #expect(proposals("Invoice 08.pdf") == ["Invoice 08"])
    }
}
