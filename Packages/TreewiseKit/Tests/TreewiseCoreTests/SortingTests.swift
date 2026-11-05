import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

/// Sorting the list, PLAN.md §4.4.
@Suite struct SortingTests {
    private let kinds = KindFormatter(locale: Locale(identifier: "en"))

    private func item(
        _ name: String, _ kind: ItemKind = .file, date: String? = nil, size: Int64? = nil,
        kindDescription: String? = nil, id: String? = nil
    ) -> FileItem {
        FileItem(
            id: FileItem.ID(id ?? name), name: name, kind: kind, volume: "hd",
            modified: date.map(Fixture.date), size: size, kindDescription: kindDescription)
    }

    private func names(_ items: [FileItem], _ sort: ItemSort) -> [String] {
        sort.sorted(items, kinds: kinds).map(\.name)
    }

    @Test func putsFoldersFirst() {
        let items = [item("b.txt"), item("Zeta", .folder), item("a.txt"), item("Alpha", .folder)]
        #expect(names(items, ItemSort()) == ["Alpha", "Zeta", "a.txt", "b.txt"])
    }

    @Test func keepsFoldersFirstWhenDescending() {
        let items = [item("a.txt"), item("Zeta", .folder), item("Alpha", .folder)]
        #expect(
            names(items, ItemSort(column: .name, ascending: false)) == ["Zeta", "Alpha", "a.txt"])
    }

    @Test func sortsNumbersInNamesByValue() {
        let items = [item("IMG_10.heic"), item("IMG_2.heic"), item("IMG_1.heic")]
        #expect(names(items, ItemSort()) == ["IMG_1.heic", "IMG_2.heic", "IMG_10.heic"])
    }

    @Test func sortsByDateWithUnknownDatesFirst() {
        let items = [
            item("new", date: "2026-10-25 18:00"), item("unknown"),
            item("old", date: "2026-01-01 09:00"),
        ]
        #expect(names(items, ItemSort(column: .dateModified)) == ["unknown", "old", "new"])
    }

    @Test func sortsBySize() {
        let items = [item("big", size: 3_000), item("small", size: 10), item("medium", size: 500)]
        #expect(names(items, ItemSort(column: .size)) == ["small", "medium", "big"])
    }

    @Test func sortsByKindText() {
        let items = [
            item("b", kindDescription: "PDF document"),
            item("a", kindDescription: "Markdown document"),
            item("c"),
        ]
        #expect(names(items, ItemSort(column: .kind)) == ["c", "a", "b"])
    }

    @Test func reversesTheColumnWhenDescending() {
        let items = [item("small", size: 10), item("big", size: 3_000)]
        #expect(names(items, ItemSort(column: .size, ascending: false)) == ["big", "small"])
    }

    @Test func breaksTiesByName() {
        let items = [item("b", size: 10), item("a", size: 10), item("c", size: 5)]
        #expect(names(items, ItemSort(column: .size)) == ["c", "a", "b"])
    }

    @Test func ordersEqualItemsTheSameWayEveryTime() {
        let items = [item("Notes", id: "2"), item("notes", id: "1"), item("NOTES", id: "3")]
        let ids = ItemSort().sorted(items, kinds: kinds).map(\.id)
        let idsReversedInput = ItemSort().sorted(items.reversed(), kinds: kinds).map(\.id)
        #expect(ids == idsReversedInput)
    }

    @Test func clickingTheSameColumnFlipsTheDirection() {
        let sort = ItemSort(column: .size).selecting(.size)
        #expect(sort == ItemSort(column: .size, ascending: false))
    }

    @Test func clickingAnotherColumnSortsItAscending() {
        let sort = ItemSort(column: .size, ascending: false).selecting(.name)
        #expect(sort == ItemSort(column: .name, ascending: true))
    }
}
