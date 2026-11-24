import Testing
import TreewiseUI

/// Treewise's own file icons on the iPad and the iPhone: kind and label from a name (ADR 0151).
@Suite struct FileBadgeTests {
    @Test(arguments: [
        ("Car insurance.pdf", FileBadge.Kind.pdf),
        ("Letter.docx", .document),
        ("Letter.doc", .document),
        ("Letter.pages", .document),
        ("Letter.rtf", .document),
        ("Budget 2026.xlsx", .spreadsheet),
        ("Budget.numbers", .spreadsheet),
        ("Export.csv", .spreadsheet),
        ("Talk.pptx", .presentation),
        ("Talk.key", .presentation),
        ("Photo.heic", .image),
        ("Photo.JPG", .image),
        ("Holiday.mov", .movie),
        ("Song.mp3", .audio),
        ("Backup.zip", .archive),
        ("Backup.tar.gz", .archive),
        ("main.swift", .code),
        ("setup.exe", .executable),
        ("Setup.EXE", .executable),
        ("Installer.msi", .executable),
        ("Installer.pkg", .executable),
        ("App.apk", .executable),
        ("Tool.jar", .executable),
        ("libtool.dylib", .executable),
        ("build.sh", .code),
        ("Start.command", .code),
        ("Notes.md", .text),
        ("Birthdays.txt", .text),
        ("Unknown.qqq", .other),
        ("README", .other),
    ])
    func kindFollowsTheType(name: String, kind: FileBadge.Kind) {
        #expect(FileBadge(fileName: name).kind == kind)
    }

    @Test(arguments: [
        ("Car insurance.pdf", "PDF"),
        ("Budget 2026.xlsx", "XLSX"),
        ("Photo.jpeg", "JPEG"),
        ("Notes.md", "MD"),
        ("Backup.tar.gz", "GZ"),
    ])
    func labelIsTheExtensionInCapitals(name: String, label: String) {
        #expect(FileBadge(fileName: name).label == label)
    }

    @Test(arguments: ["Link.webloc", "README", "Dotfile."])
    func noLabelForALongOrMissingExtension(name: String) {
        #expect(FileBadge(fileName: name).label == nil)
    }
}
