import Testing
import TreewiseCore

/// One new name for a folder in every year: where it is in its year, what each year's folder
/// does, and the template and closed missing folders corrected along (ADR 0139).
@Suite struct OneFolderNameTests {
    private static let new = "Belastingdienst"

    private func place(_ year: String, _ name: String, beside: [String] = [])
        -> OneFolderName.Place
    {
        let parent = FileItem.ID("/Admin/\(year)")
        return OneFolderName.Place(
            folder: FileItem.ID("/Admin/\(year)/\(name)"), parent: parent, name: name,
            namesBeside: beside + [name])
    }

    @Test(arguments: [
        ("/Admin/2025/Belastingsdienst", "/Admin/2025", ["Belastingsdienst"]),
        ("/Admin/2025/Q1/Belastingsdienst", "/Admin/2025", ["Q1", "Belastingsdienst"]),
        ("/2024/Projects/2025/Tax", "/2024/Projects/2025", ["Tax"]),
    ])
    func findsAFoldersPlaceInItsYear(_ folder: String, _ year: String, _ path: [String]) {
        let place = YearFolders.place(of: FileItem.ID(folder))
        #expect(place?.year == FileItem.ID(year))
        #expect(place?.path == path)
    }

    @Test(arguments: ["/Admin/2025", "/Admin/Tax", "/Admin/Tax 2025/Bank"])
    func aFolderOutsideAYearOrAYearItselfHasNoPlace(_ folder: String) {
        #expect(YearFolders.place(of: FileItem.ID(folder)) == nil)
    }

    @Test func renamesEveryFolderWithAnotherName() {
        let plan = OneFolderName(
            [place("2024", "Belastingsdienst"), place("2025", "Belastingsdienst")], to: Self.new)
        #expect(plan.entries.map(\.outcome) == [.renamed, .renamed])
        #expect(
            plan.renames == [
                BatchRename(
                    item: "/Admin/2024/Belastingsdienst", folder: "/Admin/2024",
                    from: "Belastingsdienst", to: Self.new),
                BatchRename(
                    item: "/Admin/2025/Belastingsdienst", folder: "/Admin/2025",
                    from: "Belastingsdienst", to: Self.new),
            ])
    }

    @Test func leavesAFolderAlreadyNamedSo() {
        let plan = OneFolderName([place("2026", Self.new)], to: Self.new)
        #expect(plan.entries.map(\.outcome) == [.alreadyNamed])
        #expect(plan.renames.isEmpty)
    }

    @Test func renamesAFolderThatDiffersInCaseOnly() {
        let plan = OneFolderName([place("2026", "belastingdienst")], to: Self.new)
        #expect(plan.entries.map(\.outcome) == [.renamed])
    }

    @Test func leavesOutAFolderBesideOneWithTheNewName() {
        let plan = OneFolderName(
            [place("2026", "Belastingsdienst", beside: ["belastingdienst"])], to: Self.new)
        #expect(plan.entries.map(\.outcome) == [.besideFolderNamed("belastingdienst")])
        #expect(plan.renames.isEmpty)
    }

    private let template = FolderTree(
        name: FolderTree.yearField,
        folders: [
            FolderTree(name: "Belastingsdienst", folders: [FolderTree(name: "Aangifte")]),
            FolderTree(name: "Bank"),
        ])

    @Test func correctsATemplateHoldingTheOldName() throws {
        let corrected = try #require(
            template.renamingFolder(atDiskPath: ["belastingsdienst"], to: Self.new))
        #expect(corrected.folder(at: [Self.new, "Aangifte"]) != nil)
        #expect(corrected.folder(at: ["Belastingsdienst"]) == nil)
    }

    @Test func leavesATemplateWithoutTheOldName() {
        #expect(
            template.renamingFolder(atDiskPath: ["Q1", "Belastingsdienst"], to: Self.new) == nil)
    }

    @Test func leavesATemplateThatHasTheNewNameBeside() {
        let both = FolderTree(
            name: FolderTree.yearField,
            folders: [FolderTree(name: "Belastingsdienst"), FolderTree(name: Self.new)])
        #expect(both.renamingFolder(atDiskPath: ["Belastingsdienst"], to: Self.new) == nil)
    }

    @Test func closedMissingFoldersNameTheNewPath() {
        var settings = FolderSettings(enabledModules: [], templates: [:])
        settings.missingFoldersClosed = [
            ["Belastingsdienst"], ["Belastingsdienst", "Aangifte"], ["Bank"],
        ]
        settings.renameClosedMissing(at: ["belastingsdienst"], to: Self.new)
        #expect(
            settings.missingFoldersClosed == [[Self.new], [Self.new, "Aangifte"], ["Bank"]])
    }
}
