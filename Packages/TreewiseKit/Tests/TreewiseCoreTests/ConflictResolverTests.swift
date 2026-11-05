import Testing
import TreewiseCore

/// The naming rule of PLAN.md §4.2 and ADR 0015.
@Suite struct ConflictResolverTests {
    private func name(_ name: String, _ kind: ItemKind = .file, among existing: [String]) -> String
    {
        ConflictResolver.availableName(for: name, kind: kind, among: existing)
    }

    @Test func keepsAFreeName() {
        #expect(name("Notes.md", among: ["Budget.xlsx"]) == "Notes.md")
    }

    @Test func addsCopyBeforeTheExtension() {
        #expect(name("Notes.md", among: ["Notes.md"]) == "Notes copy.md")
    }

    @Test func countsUpFromTwo() {
        #expect(name("Notes.md", among: ["Notes.md", "Notes copy.md"]) == "Notes copy 2.md")
        #expect(
            name("Notes.md", among: ["Notes.md", "Notes copy.md", "Notes copy 2.md"])
                == "Notes copy 3.md")
    }

    @Test func splitsOnlyTheLastExtension() {
        #expect(name("photo.backup.jpg", among: ["photo.backup.jpg"]) == "photo.backup copy.jpg")
    }

    @Test(arguments: ["tar.gz", "tar.bz2", "tar.xz"])
    func keepsCompoundArchiveExtensionsTogether(_ pathExtension: String) {
        let original = "archive.\(pathExtension)"
        #expect(name(original, among: [original]) == "archive copy.\(pathExtension)")
    }

    @Test(arguments: ["2026.04.28 Permit request", "Payroll 2026.09", "Report v1.2"])
    func aDotInANameWithoutExtensionStartsNoExtension(_ original: String) {
        #expect(name(original, among: [original]) == original + " copy")
    }

    @Test func neverSplitsAFolderName() {
        #expect(name("v1.2", .folder, among: ["v1.2"]) == "v1.2 copy")
    }

    @Test func keepsTheExtensionOfAPackage() {
        #expect(name("Safari.app", .package, among: ["Safari.app"]) == "Safari copy.app")
    }

    @Test func treatsALeadingDotAsPartOfTheName() {
        #expect(name(".gitignore", among: [".gitignore"]) == ".gitignore copy")
        #expect(name(".env.local", among: [".env.local"]) == ".env copy.local")
    }

    @Test func treatsATrailingDotAsPartOfTheName() {
        #expect(name("draft.", among: ["draft."]) == "draft. copy")
    }

    @Test func comparesNamesCaseInsensitively() {
        #expect(name("Notes.md", among: ["notes.md"]) == "Notes copy.md")
        #expect(name("Notes.md", among: ["notes.md", "NOTES COPY.MD"]) == "Notes copy 2.md")
    }

    @Test func treatsComposedAndDecomposedAccentsAsTheSameName() {
        let composed = "Caf\u{E9}.txt"
        let decomposed = "Cafe\u{301}.txt"
        #expect(name(composed, among: [decomposed]) == "Caf\u{E9} copy.txt")
    }
}
