import Testing
import TreewiseCore

/// Where a name's extension starts (ADR 0109).
@Suite struct FileNameTests {
    @Test(arguments: [
        ("Notes.md", ItemKind.file, "Notes", ".md"),
        ("archive.TAR.GZ", .file, "archive", ".TAR.GZ"),
        (".tar.gz", .file, ".tar", ".gz"),
        ("Payroll 2026.09", .file, "Payroll 2026.09", ""),
        ("2026.04.28 Permit", .file, "2026.04.28 Permit", ""),
        ("Photo.my file", .file, "Photo.my file", ""),
        (".gitignore", .file, ".gitignore", ""),
        ("README", .file, "README", ""),
        ("Safari.app", .package, "Safari", ".app"),
        ("Version 1.2b", .folder, "Version 1.2b", ""),
        ("Footage.v2", .volume, "Footage.v2", ""),
    ])
    func splitsANameIntoItsStemAndExtension(
        _ name: String, _ kind: ItemKind, _ stem: String, _ pathExtension: String
    ) {
        let split = FileName.split(name, kind: kind)
        #expect(split.stem == stem)
        #expect(split.pathExtension == pathExtension)
    }
}
