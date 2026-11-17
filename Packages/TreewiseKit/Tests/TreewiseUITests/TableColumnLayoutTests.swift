import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// The iPad table's columns: which show and how wide (ADR 0125).
@MainActor
@Suite struct TableColumnLayoutTests {
    @Test func showsEveryColumnAtItsDefaultWidthAtFirst() {
        let layout = TableColumnLayout()

        #expect(layout.shown == [.dateModified, .size, .kind])
        #expect(layout.width(of: .dateModified) == FolderColumn.dateModified.defaultWidth)
    }

    @Test func showsTheDatesCreatedAndAddedOnlyWhenChosen() {
        var layout = TableColumnLayout()
        #expect(!layout.isShown(.dateCreated))
        #expect(!layout.isShown(.dateAdded))

        layout.toggle(.dateAdded)

        #expect(layout.shown == [.dateModified, .dateAdded, .size, .kind])
    }

    @Test func keepsAChoiceKeptBeforeTheDatesCreatedAndAdded() throws {
        let kept = Data(#"{"hidden":["kind"],"widths":[]}"#.utf8)

        let layout = try JSONDecoder().decode(TableColumnLayout.self, from: kept)

        #expect(layout.shown == [.dateModified, .size])
    }

    @Test func hidesAndShowsAColumnInItsPlace() {
        var layout = TableColumnLayout()

        layout.toggle(.size)
        #expect(layout.shown == [.dateModified, .kind])
        layout.toggle(.size)
        #expect(layout.shown == [.dateModified, .size, .kind])
    }

    @Test(arguments: [
        (10.0, TableColumnLayout.minimumWidth), (250.0, 250.0),
        (1000.0, TableColumnLayout.maximumWidth),
    ])
    func keepsAWidthWithinItsBounds(asked: Double, kept: Double) {
        var layout = TableColumnLayout()

        layout.setWidth(asked, of: .kind)

        #expect(layout.width(of: .kind) == kept)
    }

    @Test func givesAColumnItsDefaultWidthBack() {
        var layout = TableColumnLayout()
        layout.setWidth(300, of: .kind)

        layout.resetWidth(of: .kind)

        #expect(layout.width(of: .kind) == FolderColumn.kind.defaultWidth)
    }

    @Test func isKeptInTheSettings() {
        let store = MemorySettingsStore()
        let settings = BrowserSettings(store: store)
        settings.tableColumns.toggle(.kind)
        settings.tableColumns.setWidth(222, of: .dateModified)

        let again = BrowserSettings(store: store).tableColumns

        #expect(again.shown == [.dateModified, .size])
        #expect(again.width(of: .dateModified) == 222)
    }

    // MARK: - Fitting the room there is

    /// Every column chosen, the dates 220 wide, the size 90 and the kind 160: with 20
    /// between columns they take 1,010 points.
    private var everyColumn: TableColumnLayout {
        var layout = TableColumnLayout()
        layout.toggle(.dateCreated)
        layout.toggle(.dateAdded)
        return layout
    }

    @Test func keepsEveryChosenColumnWhereThereIsRoom() {
        let fitted = everyColumn.fitted(into: 1_010, spacing: 20)

        #expect(fitted.shown == [.dateModified, .dateCreated, .dateAdded, .size, .kind])
    }

    @Test func leavesOutTheDateAddedFirstWhereThereIsTooLittleRoom() {
        let fitted = everyColumn.fitted(into: 800, spacing: 20)

        #expect(fitted.shown == [.dateModified, .dateCreated, .size, .kind])
        #expect(fitted.isCrowdedOut(.dateAdded))
        #expect(fitted.isShown(.dateAdded), "still chosen")
    }

    @Test func keepsTheDateModifiedLongest() {
        let fitted = everyColumn.fitted(into: 500, spacing: 20)

        #expect(fitted.shown == [.dateModified, .size])
    }

    @Test func showsNoColumnWhereEvenTheDateModifiedHasNoRoom() {
        let fitted = everyColumn.fitted(into: 100, spacing: 20)

        #expect(fitted.shown.isEmpty)
    }

    @Test func aColumnLeftOutIsNotKept() throws {
        let fitted = everyColumn.fitted(into: 100, spacing: 20)

        let kept = try JSONDecoder().decode(
            TableColumnLayout.self, from: try JSONEncoder().encode(fitted))

        #expect(kept == everyColumn)
    }
}
