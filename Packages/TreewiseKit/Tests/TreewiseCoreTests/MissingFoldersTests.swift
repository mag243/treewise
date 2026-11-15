import Testing
import TreewiseCore

/// The folders of the year before that a year's folder lacks, and adding them to the template
/// (ADR 0102).
@Suite struct MissingFoldersTests {
    private static let english = FolderTemplateValues(year: 2027, language: .english)
    private static let names = FolderNameSettings(
        enabledModules: ["free"], moduleOrder: [], patterns: [:])

    /// The year before, filled in for 2027.
    private static let made = FolderTree(
        name: "2027",
        folders: [
            FolderTree(
                name: "Tax",
                folders: [
                    FolderTree(name: "Returns"),
                    FolderTree(name: "Appeals", folders: [FolderTree(name: "Letters")]),
                ]),
            FolderTree(name: "Receipts"),
        ])

    @Test func listsTheFoldersTheYearLacksWithThoseTheyAreIn() {
        let there = FolderContents(folders: [
            "Tax": FolderContents(folders: ["Returns": FolderContents()]),
            "Receipts": FolderContents(),
        ])
        let missing = MissingFolders(of: Self.made, in: there)
        #expect(missing.paths == [["Tax", "Appeals"]])
        #expect(
            missing.tree
                == FolderTree(
                    name: "2027",
                    folders: [
                        FolderTree(
                            name: "Tax",
                            folders: [
                                FolderTree(name: "Appeals", folders: [FolderTree(name: "Letters")])
                            ])
                    ]))
    }

    @Test func countsAMissingFolderOnceWithTheFoldersInIt() {
        let missing = MissingFolders(of: Self.made, in: FolderContents())
        #expect(missing.paths == [["Receipts"], ["Tax"]])
        #expect(missing.tree == Self.made)
    }

    @Test func comparesNamesWithoutCaseAndKeepsTheNameOnDisk() {
        let there = FolderContents(folders: [
            "tax": FolderContents(folders: ["returns": FolderContents()]),
            "RECEIPTS": FolderContents(),
        ])
        let missing = MissingFolders(of: Self.made, in: there)
        #expect(missing.paths == [["tax", "Appeals"]])
        #expect(missing.tree.folders.map(\.name) == ["tax"])
    }

    @Test func aFileWithTheNameOfAFolderIsNotMissing() {
        let there = FolderContents(
            folders: ["Tax": FolderContents(folders: ["Returns": FolderContents()])],
            files: ["Receipts"])
        let tax = FolderContents(
            folders: ["Returns": FolderContents()], files: ["Appeals"])
        #expect(MissingFolders(of: Self.made, in: there).paths == [["Tax", "Appeals"]])
        let none = MissingFolders(
            of: Self.made, in: FolderContents(folders: ["Tax": tax], files: ["Receipts"]))
        #expect(none.isEmpty)
    }

    @Test func nothingIsMissingWhenEveryFolderIsThere() {
        let there = FolderContents(folders: [
            "Tax": FolderContents(folders: [
                "Returns": FolderContents(),
                "Appeals": FolderContents(folders: ["Letters": FolderContents()]),
            ]),
            "Receipts": FolderContents(),
            "Extra": FolderContents(),
        ])
        let missing = MissingFolders(of: Self.made, in: there)
        #expect(missing.isEmpty)
        #expect(missing.tree.folders.isEmpty)
    }

    @Test func leavesOutTheFoldersClosedWhateverTheirCase() {
        let there = FolderContents(folders: ["Tax": FolderContents()])
        let missing = MissingFolders(
            of: Self.made, in: there, leavingOut: [["tax", "returns"], ["Receipts"]])
        #expect(missing.paths == [["Tax", "Appeals"]])
        #expect(missing.tree.folders.first?.folders.map(\.name) == ["Appeals"])
    }

    @Test func aMissingFolderKeepsItsNameSettings() {
        let made = FolderTree(
            name: "2027", folders: [FolderTree(name: "Invoices", names: Self.names)])
        let missing = MissingFolders(of: made, in: FolderContents())
        #expect(missing.tree.folders.first?.names == Self.names)
    }

    // MARK: Adding to the template

    private static let recognized = FolderTree(
        name: "{year}",
        folders: [
            FolderTree(
                name: "Tax",
                folders: [
                    FolderTree(name: "Returns"),
                    FolderTree(name: "Appeals", names: names),
                ]),
            FolderTree(name: "Receipts"),
        ])

    @Test func addsTheMissingFoldersTheTemplateLacksAndNoOthers() throws {
        let template = FolderTree(
            name: "{year}",
            folders: [FolderTree(name: "Tax", folders: [FolderTree(name: "Returns")])])
        let missing = MissingFolders(
            of: Self.made,
            in: FolderContents(folders: [
                "Tax": FolderContents(folders: ["Returns": FolderContents()]),
                "Receipts": FolderContents(),
            ]))
        let added = try #require(
            template.adding(missing, from: Self.recognized, values: Self.english))
        #expect(added.folder(at: ["Tax"])?.folders.map(\.name) == ["Appeals", "Returns"])
        #expect(added.folder(at: ["Tax", "Appeals"])?.names == Self.names)
        #expect(added.folder(at: ["Receipts"]) == nil, "2027 has Receipts")
    }

    @Test func addsNothingWhenTheTemplateHasTheMissingFolders() {
        let missing = MissingFolders(of: Self.made, in: FolderContents())
        let template = Self.recognized
        #expect(template.adding(missing, from: Self.recognized, values: Self.english) == nil)
    }

    @Test func addsAFolderBelowARepeatingFolderOnce() throws {
        let recognized = FolderTree(
            name: "{year}",
            folders: [
                FolderTree(
                    name: "{quarter}",
                    folders: [FolderTree(name: "Invoices"), FolderTree(name: "Paid")])
            ])
        let template = FolderTree(
            name: "{year}",
            folders: [FolderTree(name: "{quarter}", folders: [FolderTree(name: "Invoices")])])
        let made = recognized.filling(folderNamed: "2027").filling(Self.english)
        let quarters = Dictionary(
            uniqueKeysWithValues: made.folders.map {
                ($0.name, FolderContents(folders: ["Invoices": FolderContents()]))
            })
        let missing = MissingFolders(of: made, in: FolderContents(folders: quarters))
        #expect(missing.paths.count == 4)
        let added = try #require(template.adding(missing, from: recognized, values: Self.english))
        #expect(added.folders.count == 1)
        #expect(added.folder(at: ["{quarter}"])?.folders.map(\.name) == ["Invoices", "Paid"])
    }

    @Test func addsAFolderWhoseNameHoldsTheYear() throws {
        let recognized = FolderTree(
            name: "{year}", folders: [FolderTree(name: "Annual Report {year}")])
        let made = recognized.filling(folderNamed: "2027").filling(Self.english)
        let missing = MissingFolders(of: made, in: FolderContents())
        #expect(missing.paths == [["Annual Report 2027"]])
        let added = try #require(
            FolderTree(name: "{year}").adding(missing, from: recognized, values: Self.english))
        #expect(added.folders.map(\.name) == ["Annual Report {year}"])
    }
}
