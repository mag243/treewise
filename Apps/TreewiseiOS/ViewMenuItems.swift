import SwiftUI
import TreewiseCore
import TreewiseUI

/// The View menu's sorting and showing, in the View menu and, on a compact width, in the
/// folder's one menu (ADR 0132).
struct ViewMenuItems: View {
    let browser: BrowserState
    @Bindable var settings: BrowserSettings

    var body: some View {
        Picker("Sort By", selection: column) {
            Text("Name").tag(SortColumn.name)
            Text("Date Modified").tag(SortColumn.dateModified)
            Text("Size").tag(SortColumn.size)
            Text("Kind").tag(SortColumn.kind)
        }
        Picker("Order", selection: ascending) {
            Text("Ascending").tag(true)
            Text("Descending").tag(false)
        }
        Divider()
        Toggle("Show Hidden Files", isOn: $settings.showsHiddenFiles)
        Toggle("Show File Extensions", isOn: $settings.showsExtensions)
    }

    private var column: Binding<SortColumn> {
        Binding(
            get: { browser.sort.column },
            set: { browser.sort(by: $0, ascending: browser.sort.ascending) })
    }

    private var ascending: Binding<Bool> {
        Binding(
            get: { browser.sort.ascending },
            set: { browser.sort(by: browser.sort.column, ascending: $0) })
    }
}
