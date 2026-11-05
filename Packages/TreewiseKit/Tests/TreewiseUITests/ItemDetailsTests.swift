import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// What the details pane says about the selection (M5b).
@Suite struct ItemDetailsTests {
    private let locale = Locale(identifier: "en_GB")
    private let zone = TimeZone(identifier: "Europe/Amsterdam") ?? .gmt
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    /// 24 Oct 2026 at 21:14 in Amsterdam.
    private let modified = Date(timeIntervalSince1970: 1_792_869_240)
    /// Over two weeks later, so the date is not today or yesterday.
    private let now = Date(timeIntervalSince1970: 1_794_251_640)

    private func file(_ name: String, size: Int64) -> FileItem {
        FileItem(
            id: FileItem.ID("/Users/x/\(name)"), name: name, kind: .file, parentID: "/Users/x",
            volume: "hd", modified: modified, size: size, kindDescription: "Markdown document")
    }

    private func details(_ items: [FileItem]) -> ItemDetails {
        ItemDetails(
            items, calendar: calendar, locale: locale, timeZone: zone, now: now)
    }

    @Test func describesOneItem() {
        let details = details([file("Notes.md", size: 1_840_000)])
        #expect(details.title == "Notes.md")
        #expect(
            details.rows == [
                .init(label: "Kind", value: "Markdown document"),
                .init(label: "Size", value: "1.8 MB"),
                .init(label: "Date Modified", value: "24 Oct 2026 at 21:14"),
                .init(label: "Where", value: "/Users/x"),
            ])
        #expect(details.previewItem == "/Users/x/Notes.md")
    }

    @Test func leavesOutTheSizeOfAFolder() {
        let folder = FileItem(
            id: "/Users/x/Projects", name: "Projects", kind: .folder, parentID: "/Users/x",
            volume: "hd")
        #expect(!details([folder]).rows.contains { $0.label == "Size" })
    }

    @Test func countsSeveralItemsAndAddsUpTheirSize() {
        let details = details([file("a.md", size: 1_000_000), file("b.md", size: 800_000)])
        #expect(details.title == "2 items")
        #expect(details.rows == [.init(label: "Size", value: "1.8 MB")])
        #expect(details.previewItem == nil)
    }

    @Test func saysNothingIsSelected() {
        let details = details([])
        #expect(details.title == "No selection")
        #expect(details.rows.isEmpty)
    }
}
