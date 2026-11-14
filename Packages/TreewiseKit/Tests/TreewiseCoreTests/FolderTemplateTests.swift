import Foundation
import Testing
import TreewiseCore

/// A folder structure template: what is saved from a folder, and its file (ADR 0091).
@Suite struct FolderTemplateTests {
    private static let year = FolderTree(
        name: "{year}",
        folders: [
            FolderTree(name: "Tax"),
            FolderTree(name: "Receipts", folders: [FolderTree(name: "Receipts Kept")]),
            FolderTree(name: "Summary {year}"),
        ])

    private func item(_ name: String, _ kind: ItemKind, hidden: Bool = false) -> FileItem {
        FileItem(
            id: FileItem.ID("/x/\(name)"), name: name, kind: kind, volume: "v", isHidden: hidden)
    }

    @Test func keepsOnlyFolders() {
        #expect(FolderTree.keeps(item("Tax", .folder)))
        #expect(!FolderTree.keeps(item("Notes.md", .file)), "no files")
        #expect(!FolderTree.keeps(item("Photos.photoslibrary", .package)), "no packages")
        #expect(!FolderTree.keeps(item(".git", .folder, hidden: true)), "no hidden folders")
    }

    @Test func ordersItsFoldersByName() {
        let tree = FolderTree(
            name: "2026",
            folders: [
                FolderTree(name: "Tax"), FolderTree(name: "Receipts 10"),
                FolderTree(name: "Receipts 9"),
            ])
        #expect(tree.folders.map(\.name) == ["Receipts 9", "Receipts 10", "Tax"])
    }

    @Test func knowsWhetherItHasAYear() {
        #expect(FolderTemplate(name: "Administration year", root: Self.year).hasYear)
        #expect(
            !FolderTemplate(
                name: "Client",
                root: FolderTree(
                    name: "Client",
                    folders: [
                        FolderTree(name: "Quotes")
                    ])
            ).hasYear)
    }

    @Test func fillsInTheYear() {
        let filled = Self.year.filling(year: 2027)
        #expect(filled.name == "2027")
        #expect(filled.folders.map(\.name) == ["Receipts", "Summary 2027", "Tax"])
        #expect(filled.folders[0].folders.map(\.name) == ["Receipts Kept"])
    }

    @Test func readsBackWhatItWrote() throws {
        let template = FolderTemplate(name: "Administration year", root: Self.year)
        let data = try FolderTemplateFile.data(of: template)
        #expect(try FolderTemplateFile.template(from: data, id: template.id) == template)
    }

    @Test func readsBackATemplateWhoseNamesHoldFieldsWithAColon() throws {
        let shoot = FolderTree(
            name: "{date:yyyy-MM-dd} Shoot", folders: [FolderTree(name: "{text:upper}")])
        let template = FolderTemplate(name: "Photo Shoot", root: shoot)
        let data = try FolderTemplateFile.data(of: template)
        #expect(try FolderTemplateFile.template(from: data, id: template.id) == template)
    }

    @Test func ordersTheFoldersOfAFileByName() throws {
        let json = #"""
            {"format": 1, "name": "Year", "root": {"name": "{year}", "folders": [
                {"name": "Tax", "folders": []}, {"name": "Receipts", "folders": []}]}}
            """#
        let template = try FolderTemplateFile.template(from: Data(json.utf8), id: "t")
        #expect(template.root.folders.map(\.name) == ["Receipts", "Tax"])
    }

    @Test func ordersTheFoldersItDecodesByName() throws {
        let json = #"{"name": "2027", "folders": [{"name": "Tax"}, {"name": "Receipts"}]}"#
        let tree = try JSONDecoder().decode(FolderTree.self, from: Data(json.utf8))
        #expect(tree.folders.map(\.name) == ["Receipts", "Tax"])
    }

    @Test func refusesAFileOfANewerFormat() throws {
        let json = #"{"format": 99, "name": "Later", "root": {"name": "A", "folders": []}}"#
        #expect(throws: FolderTemplateFile.Problem.newerFormat) {
            try FolderTemplateFile.template(from: Data(json.utf8), id: "t")
        }
    }

    @Test func refusesAFileThatIsNoTemplate() {
        #expect(throws: FolderTemplateFile.Problem.unreadable) {
            try FolderTemplateFile.template(from: Data("not json".utf8), id: "t")
        }
    }

    @Test func refusesAFileWithAFolderThatCannotBeMade() {
        let json = #"{"format": 1, "name": "Bad", "root": {"name": "../Up", "folders": []}}"#
        #expect(throws: FolderTemplateFile.Problem.folders(.invalidName("../Up"))) {
            try FolderTemplateFile.template(from: Data(json.utf8), id: "t")
        }
    }
}
