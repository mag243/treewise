import Testing
import TreewiseCore

/// Which names are archives, and the names of what extracting and compressing
/// make (ADR 0074).
@Suite struct ArchiveNamingTests {
    @Test(arguments: [
        "a.zip", "a.tar", "a.tar.gz", "a.tgz", "a.tar.bz2", "a.tar.xz", "a.7z", "a.rar", "a.iso",
        "a.cpio", "a.xar",
    ])
    func recognizesTheFormatsThatPassedTheTrial(_ name: String) {
        #expect(ArchiveNaming.isArchive(name: name, kind: .file))
    }

    @Test func recognizesAnExtensionInAnyCase() {
        #expect(ArchiveNaming.isArchive(name: "Photos.ZIP", kind: .file))
        #expect(ArchiveNaming.isArchive(name: "Photos.Tar.GZ", kind: .file))
    }

    @Test(arguments: ["Notes.md", "archive", "a.gz", "a.zst", "a.tar.zst", "zip", "a zip"])
    func otherNamesAreNoArchives(_ name: String) {
        #expect(!ArchiveNaming.isArchive(name: name, kind: .file))
    }

    @Test(arguments: [".zip", ".tar.gz"])
    func aNameThatIsOnlyAnExtensionIsNoArchive(_ name: String) {
        #expect(!ArchiveNaming.isArchive(name: name, kind: .file))
    }

    @Test(arguments: ItemKind.allCases.filter { $0 != .file })
    func onlyAFileIsAnArchive(_ kind: ItemKind) {
        #expect(!ArchiveNaming.isArchive(name: "Photos.zip", kind: kind))
    }

    @Test(arguments: ["Photos.zip", "Photos.tar.gz", "Photos.tgz", "Photos.7z", "Photos.ISO"])
    func extractsToAFolderNamedAfterTheArchive(_ archive: String) {
        #expect(ArchiveNaming.extractionFolderName(for: archive, among: []) == "Photos")
    }

    @Test func removesOnlyTheArchivesOwnExtension() {
        #expect(ArchiveNaming.extractionFolderName(for: "v1.2.zip", among: []) == "v1.2")
        #expect(ArchiveNaming.extractionFolderName(for: "data.csv.zip", among: []) == "data.csv")
    }

    @Test func aTakenFolderNameGetsCopyAtItsEnd() {
        #expect(
            ArchiveNaming.extractionFolderName(for: "v1.2.zip", among: ["v1.2"]) == "v1.2 copy")
        #expect(
            ArchiveNaming.extractionFolderName(for: "Photos.zip", among: ["photos", "Photos copy"])
                == "Photos copy 2")
    }

    @Test func comparesAFolderNameUnicodeNormalised() {
        #expect(
            ArchiveNaming.extractionFolderName(for: "Caf\u{E9}.zip", among: ["Cafe\u{301}"])
                == "Caf\u{E9} copy")
    }

    @Test(arguments: [
        (ArchiveFormat.zip, "Photos.zip"), (.sevenZip, "Photos.7z"), (.tarGzip, "Photos.tar.gz"),
    ])
    func namesANewArchiveAfterAFolder(_ format: ArchiveFormat, _ expected: String) {
        #expect(
            ArchiveNaming.newArchiveName(
                after: "Photos", kind: .folder, format: format, among: []) == expected)
    }

    @Test func keepsADotInAFolderName() {
        #expect(
            ArchiveNaming.newArchiveName(after: "v1.2", kind: .folder, format: .zip, among: [])
                == "v1.2.zip")
    }

    @Test(arguments: [
        ("Notes.md", ItemKind.file), ("Notes.tar.gz", .file), ("Notes.app", .package),
    ])
    func aNewArchiveReplacesTheExtensionOfTheClickedItem(_ name: String, _ kind: ItemKind) {
        #expect(
            ArchiveNaming.newArchiveName(after: name, kind: kind, format: .zip, among: [])
                == "Notes.zip")
    }

    @Test func aHiddenFileKeepsItsWholeName() {
        #expect(
            ArchiveNaming.newArchiveName(after: ".env", kind: .file, format: .zip, among: [])
                == ".env.zip")
    }

    @Test func aTakenArchiveNameGetsCopyBeforeTheExtension() {
        #expect(
            ArchiveNaming.newArchiveName(
                after: "Photos", kind: .folder, format: .zip, among: ["photos.ZIP"])
                == "Photos copy.zip")
        #expect(
            ArchiveNaming.newArchiveName(
                after: "Photos", kind: .folder, format: .tarGzip,
                among: ["Photos.tar.gz", "Photos copy.tar.gz"])
                == "Photos copy 2.tar.gz")
    }
}
