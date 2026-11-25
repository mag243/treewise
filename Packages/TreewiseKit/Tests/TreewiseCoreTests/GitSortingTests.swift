import Foundation
import Testing
import TreewiseCore

/// Sorting the list by the Git column (ADR 0149): what needs attention first.
@Suite struct GitSortingTests {
    private let kinds = KindFormatter(locale: Locale(identifier: "en"))
    private let states: [String: GitItemState] = [
        "changed.txt": .modified, "fresh.txt": .new, "debug.log": .ignored,
        "clash.txt": .conflict, "Sources": .modified,
    ]

    private func names(_ names: [String], ascending: Bool = true) -> [String] {
        let items = names.map { name in
            FileItem(
                id: FileItem.ID(name), name: name, kind: name.contains(".") ? .file : .folder,
                volume: "hd")
        }
        return ItemSort(column: .git, ascending: ascending)
            .sorted(items, kinds: kinds) { states[$0.id.rawValue] }
            .map(\.name)
    }

    @Test func putsAConflictFirstThenModifiedNewIgnoredAndUnchanged() {
        #expect(
            names(["same.txt", "debug.log", "fresh.txt", "changed.txt", "clash.txt"])
                == ["clash.txt", "changed.txt", "fresh.txt", "debug.log", "same.txt"])
    }

    @Test func descendingPutsUnchangedFirst() {
        #expect(
            names(["changed.txt", "same.txt", "clash.txt"], ascending: false)
                == ["same.txt", "changed.txt", "clash.txt"])
    }

    @Test func keepsFoldersFirst() {
        #expect(names(["clash.txt", "Docs", "Sources"]) == ["Sources", "Docs", "clash.txt"])
    }

    @Test func withoutStatesTheNameDecides() {
        let items = ["b.txt", "a.txt"].map {
            FileItem(id: FileItem.ID($0), name: $0, kind: .file, volume: "hd")
        }
        #expect(
            ItemSort(column: .git).sorted(items, kinds: kinds).map(\.name) == ["a.txt", "b.txt"])
    }
}
