import Testing
import TreewiseCore

/// The name the list shows, with or without the extension (ADR 0023).
@Suite struct DisplayNameTests {
    private func item(_ name: String, _ kind: ItemKind) -> FileItem {
        FileItem(id: FileItem.ID(name), name: name, kind: kind, volume: "disk")
    }

    @Test(arguments: [
        ("Notes.md", ItemKind.file, "Notes"),
        ("archive.tar.gz", .file, "archive.tar"),
        ("Safari.app", .package, "Safari"),
        ("README", .file, "README"),
        (".gitignore", .file, ".gitignore"),
        ("Version 1.2", .folder, "Version 1.2"),
        ("Footage.v2", .volume, "Footage.v2"),
    ])
    func hidesTheLastExtensionOfFilesAndPackages(_ name: String, _ kind: ItemKind, _ shown: String)
    {
        #expect(DisplayName.text(for: item(name, kind), showsExtension: false) == shown)
    }

    @Test func showsTheFullNameWithExtensions() {
        #expect(DisplayName.text(for: item("Notes.md", .file), showsExtension: true) == "Notes.md")
    }

    @Test func itemsAreNotHiddenUnlessTheProviderSaysSo() {
        #expect(!item("Notes.md", .file).isHidden)
    }
}
