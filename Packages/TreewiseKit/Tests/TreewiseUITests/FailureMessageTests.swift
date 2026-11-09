import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// What the window says when an operation fails (ADR 0018).
@Suite struct FailureMessageTests {
    private let english = Locale(identifier: "en")

    @Test(arguments: [
        (
            FileSystemError.alreadyExists("/Users/x/Notes.md"),
            "An item named “Notes.md” already exists in this location."
        ),
        (.notWritable("/Volumes/CD"), "You don’t have permission to change “CD”."),
        (.invalidName("a/b"), "The name “a/b” can’t be used."),
        (
            .trashUnavailable("/Volumes/T7/x.txt"),
            "“x.txt” can’t be moved to the Trash because its volume has no Trash."
        ),
        (.cancelled, "The operation was stopped."),
        (
            .outsideBoundary("/Users/x/Secret.md"),
            "“Secret.md” is outside the folders Treewise may use now."
        ),
        (
            .notEnoughSpace("/Users/x/Raw footage"),
            "There isn’t enough space to copy “Raw footage”."
        ),
        (.archiveDamaged("/Users/x/Photos.zip"), "“Photos.zip” is damaged and can’t be extracted."),
        (
            .archivePasswordProtected("/Users/x/Photos.zip"),
            "“Photos.zip” is protected with a password."
        ),
        (
            .archiveFormatUnknown("/Users/x/Photos.zip"),
            "“Photos.zip” isn’t in a format Treewise can extract."
        ),
        (.unexpected("The disk was ejected."), "The operation failed: The disk was ejected."),
        (
            .notEjected("/Volumes/T7", "It is in use by another app."),
            "“T7” can’t be ejected. It is in use by another app."
        ),
    ])
    func explainsWhatWentWrong(_ failure: FileSystemError, _ expected: String) {
        #expect(FailureMessage.text(for: failure, locale: english) == expected)
    }
}
