import Foundation
import Testing
import TreewiseUI

/// The status bar under each pane: "8 items, 245.3 GB available".
@Suite struct StatusLineTests {
    private let locale = Locale(identifier: "en_GB")

    @Test func countsTheItemsAndTheFreeSpace() {
        #expect(
            StatusLine.text(
                itemCount: 8, selectedCount: 0, availableCapacity: 245_300_000_000, locale: locale)
                == "8 items, 245.3 GB available")
    }

    @Test(.tags(.localization), .needsCompiledStrings) func usesTheSingularForOneItem() {
        #expect(
            StatusLine.text(itemCount: 1, selectedCount: 0, availableCapacity: nil, locale: locale)
                == "1 item")
    }

    @Test func showsHowManyItemsAreSelectedAndTheirSize() {
        #expect(
            StatusLine.text(
                itemCount: 8, selectedCount: 2, selectedSize: 1_840_000,
                availableCapacity: 245_300_000_000,
                locale: locale) == "2 of 8 items selected, 1.8 MB")
    }

    @Test func leavesOutTheSizeOfASelectionOfFolders() {
        #expect(
            StatusLine.text(
                itemCount: 8, selectedCount: 1, selectedSize: 0, availableCapacity: nil,
                locale: locale)
                == "1 of 8 items selected")
    }

    /// The size is written by Foundation (German puts a non-breaking space
    /// before the unit); the test checks the words around it.
    @Test(
        .tags(.localization), .needsCompiledStrings,
        arguments: [
            ("nl_NL", "8 onderdelen, %@ beschikbaar"), ("de_DE", "8 Objekte, %@ verfügbar"),
        ])
    func speaksTheLanguageOfTheLocale(_ identifier: String, _ pattern: String) {
        let locale = Locale(identifier: identifier)
        let free = Int64(245_300_000_000).formatted(.byteCount(style: .file).locale(locale))
        #expect(
            StatusLine.text(
                itemCount: 8, selectedCount: 0, availableCapacity: 245_300_000_000, locale: locale)
                == pattern.replacingOccurrences(of: "%@", with: free))
    }
}
