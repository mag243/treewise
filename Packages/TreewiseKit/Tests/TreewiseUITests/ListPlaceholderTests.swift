import Foundation
import Testing
import TreewiseUI

/// What an empty list says instead of rows.
@Suite struct ListPlaceholderTests {
    private let english = Locale(identifier: "en_GB")

    @Test func saysAFolderIsEmpty() {
        #expect(ListPlaceholder.text(query: "", locale: english) == "Folder is empty")
    }

    @Test func saysASearchFoundNothing() {
        #expect(ListPlaceholder.text(query: "notes", locale: english) == "No results for “notes”")
    }

    @Test(.tags(.localization), .needsCompiledStrings) func speaksDutch() {
        #expect(
            ListPlaceholder.text(query: "", locale: Locale(identifier: "nl_NL")) == "Map is leeg")
    }
}
