import Foundation
import Testing
import TreewiseCore

/// Names for new folders and the check on names the user types (ADR 0018).
@Suite struct FolderNamingTests {
    private let english = Locale(identifier: "en")

    @Test func namesANewFolderUntitledFolder() {
        #expect(
            FolderNaming.newFolderName(among: ["Notes.md"], locale: english) == "untitled folder")
    }

    @Test func numbersItFromTwoWhenTaken() {
        let taken = ["untitled folder", "Untitled Folder 2"]
        #expect(FolderNaming.newFolderName(among: taken, locale: english) == "untitled folder 3")
    }

    @Test(.tags(.localization), .needsCompiledStrings)
    func speaksTheLanguageOfTheLocale() {
        #expect(
            FolderNaming.newFolderName(among: [], locale: Locale(identifier: "nl"))
                == "naamloze map")
    }

    @Test(arguments: ["Notes.md", ".hidden", "a b", "café"])
    func acceptsOrdinaryNames(_ name: String) {
        #expect(FolderNaming.isValidName(name))
    }

    @Test(arguments: ["", "   ", ".", "..", "a/b", "a:b"])
    func rejectsNamesTheFileSystemCannotHold(_ name: String) {
        #expect(!FolderNaming.isValidName(name))
    }
}
