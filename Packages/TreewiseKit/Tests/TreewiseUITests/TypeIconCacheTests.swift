import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseUI

/// The system's file icons on the iPad, made once per type (ADR 0148).
@MainActor
@Suite struct TypeIconCacheTests {
    /// An icon the test's maker made, by the file it was made from.
    final class Icon: Sendable {
        let madeFrom: String
        init(madeFrom: String) { self.madeFrom = madeFrom }
    }

    /// A maker that counts how often it is asked, and makes an icon at once or never.
    final class Maker: Sendable {
        private let asked = Mutex(0)
        let gives: Bool
        init(gives: Bool = true) { self.gives = gives }
        var timesAsked: Int { asked.withLock { $0 } }

        func make(_ item: FileItem, _ size: Int) async -> Icon? {
            asked.withLock { $0 += 1 }
            await Task.yield()
            return gives ? Icon(madeFrom: item.name) : nil
        }
    }

    private static func file(_ name: String) -> FileItem {
        FileItem(
            id: FileItem.ID("/f/\(name)"), name: name, kind: .file, parentID: "/f",
            volume: VolumeID("/"))
    }

    @Test func makesOneIconForEveryFileOfAType() async {
        let maker = Maker()
        let cache = TypeIconCache<Icon>(make: maker.make)

        let first = await cache.icon(for: Self.file("Invoice.pdf"), size: 20)
        let second = await cache.icon(for: Self.file("Letter.PDF"), size: 20)

        #expect(first === second, "the PDF's icon is kept for every PDF")
        #expect(maker.timesAsked == 1)
        #expect(cache.cachedIcon(for: Self.file("Report.pdf"), size: 20) === first)
    }

    @Test func makesAnIconPerTypeAndSize() async {
        let maker = Maker()
        let cache = TypeIconCache<Icon>(make: maker.make)

        _ = await cache.icon(for: Self.file("Invoice.pdf"), size: 20)
        _ = await cache.icon(for: Self.file("Budget.xlsx"), size: 20)
        _ = await cache.icon(for: Self.file("Invoice.pdf"), size: 40)

        #expect(maker.timesAsked == 3)
    }

    @Test func asksOnceForATypeBeingMade() async {
        let maker = Maker()
        let cache = TypeIconCache<Icon>(make: maker.make)

        async let first = cache.icon(for: Self.file("A.pdf"), size: 20)
        async let second = cache.icon(for: Self.file("B.pdf"), size: 20)
        let icons = await [first, second]

        #expect(maker.timesAsked == 1, "the second waits for the first's request")
        #expect(icons[0] === icons[1])
    }

    @Test func givesNoIconForANameWithoutAType() async {
        let maker = Maker()
        let cache = TypeIconCache<Icon>(make: maker.make)

        #expect(await cache.icon(for: Self.file("README"), size: 20) == nil)
        #expect(maker.timesAsked == 0, "the symbol stays; nothing is asked")
    }

    @Test func asksAgainWhenNoIconWasMade() async {
        let maker = Maker(gives: false)
        let cache = TypeIconCache<Icon>(make: maker.make)

        #expect(await cache.icon(for: Self.file("A.pdf"), size: 20) == nil)
        #expect(cache.cachedIcon(for: Self.file("A.pdf"), size: 20) == nil)
    }
}
