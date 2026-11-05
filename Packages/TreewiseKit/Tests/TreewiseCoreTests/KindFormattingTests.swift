import Foundation
import Testing
import TreewiseCore

/// The Kind column: the provider's description, or a generic one per kind.
@Suite struct KindFormattingTests {
    private let formatter = KindFormatter(locale: Locale(identifier: "en"))

    private func text(_ kind: ItemKind, _ description: String? = nil) -> String {
        formatter.string(
            for: FileItem(
                id: "x", name: "x", kind: kind, volume: "hd", kindDescription: description))
    }

    @Test func usesTheProvidersDescription() {
        #expect(text(.file, "PDF document") == "PDF document")
    }

    @Test(arguments: [
        (ItemKind.folder, "Folder"), (.file, "Document"), (.package, "Application"),
        (.volume, "Volume"), (.cloud, "Cloud storage"),
    ])
    func fallsBackToADescriptionOfTheKind(_ kind: ItemKind, _ expected: String) {
        #expect(text(kind) == expected)
    }
}
