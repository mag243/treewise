import Foundation
import Testing
import TreewiseCore

/// Sizes in the list, PLAN.md §4.4: decimal units, two dashes for containers.
@Suite struct SizeFormattingTests {
    private let formatter = ItemSizeFormatter(locale: Locale(identifier: "en_GB"))

    private func text(_ size: Int64?, _ kind: ItemKind = .file) -> String {
        formatter.string(for: FileItem(id: "x", name: "x", kind: kind, volume: "hd", size: size))
    }

    @Test(arguments: [
        (Int64(800), "800 bytes"), (6_100, "6 kB"), (1_840_000, "1.8 MB"),
        (3_420_000_000, "3.42 GB"),
    ])
    func writesDecimalUnits(_ size: Int64, _ expected: String) {
        #expect(text(size) == expected)
    }

    @Test func writesZeroInWords() {
        #expect(text(0) == "Zero kB")
    }

    @Test(arguments: [ItemKind.folder, .volume, .cloud])
    func writesTwoDashesForContainers(_ kind: ItemKind) {
        #expect(text(nil, kind) == "--")
    }

    @Test func writesTwoDashesForAnUnknownSize() {
        #expect(text(nil) == "--")
    }
}
