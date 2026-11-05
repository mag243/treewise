import SwiftUI
import TreewiseCore
import TreewiseUI

/// The toolbar's View menu: the sort order, which a narrow list has no
/// headers for, and the settings shared with the Mac.
struct ViewMenu: View {
    let browser: BrowserState
    @Bindable var settings: BrowserSettings

    var body: some View {
        Menu {
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
        } label: {
            Label("View", systemImage: "ellipsis.circle")
        }
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
