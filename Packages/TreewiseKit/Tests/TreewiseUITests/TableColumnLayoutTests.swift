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
}
