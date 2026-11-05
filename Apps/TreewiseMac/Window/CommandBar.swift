import SwiftUI
import TreewiseCore
import TreewiseUI

/// Explorer's command bar as a row of the window, under the tab bar (ADR
/// 0037): New, the actions (ADR 0036), Sort and View as menus with a label,
/// and Window Beside and the details pane at the end.
struct CommandBar: View {
    private static let height: CGFloat = 34
    private static let padding: CGFloat = 8
    private static let dividerHeight: CGFloat = 18

    let browser: BrowserState
    let undoManager: UndoManager?
    /// Opens a window beside this one (⌥⌘N).
    let windowBeside: () -> Void

    var body: some View {
        // In a narrow window the menus and buttons drop their titles and keep
        // their icons, so nothing wraps or is cut off.
        ViewThatFits(in: .horizontal) {
            row.labelStyle(.titleAndIcon)
            row.labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Self.padding)
        .frame(height: Self.height)
    }

    private var row: some View {
        HStack(spacing: Self.padding) {
            newMenu
            divider
            CommandBarActions(browser: browser, undoManager: undoManager)
            divider
            sortMenu
            viewMenu
            Spacer(minLength: 0)
            Button("Window Beside", systemImage: "rectangle.split.2x1", action: windowBeside)
                .buttonStyle(.borderless)
                .fixedSize()
                .help(Text("Open a window beside this one"))
            Toggle(isOn: showsDetails) {
                Label("Details", systemImage: "sidebar.right")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
            .help(Text("Show or hide the details pane"))
        }
    }

    private var divider: some View {
        Divider().frame(height: Self.dividerHeight)
    }

    private var newMenu: some View {
        Menu {
            Button("New Folder", systemImage: "folder.badge.plus") {
                Task { await browser.newFolder(undoManager: undoManager) }
            }
            .disabled(!browser.canAddItems)
        } label: {
            Label("New", systemImage: "plus.circle")
        }
        .fixedSize()
        .help(Text("Make something new in this folder"))
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: sortColumn) {
                Text("Name").tag(SortColumn.name)
                Text("Date Modified").tag(SortColumn.dateModified)
                Text("Kind").tag(SortColumn.kind)
                Text("Size").tag(SortColumn.size)
            }
            .pickerStyle(.inline)
            Picker("Order", selection: ascending) {
                Text("Ascending").tag(true)
                Text("Descending").tag(false)
            }
            .pickerStyle(.inline)
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .fixedSize()
    }

    private var viewMenu: some View {
        @Bindable var settings = browser.settings
        return Menu {
            Picker("View", selection: viewMode) {
                Label("as Icons", systemImage: "square.grid.2x2").tag(ViewMode.icons)
                Label("as List", systemImage: "list.bullet").tag(ViewMode.list)
            }
            .pickerStyle(.inline)
            Picker("Row Size", selection: $settings.rowDensity) {
                Text("Small").tag(RowDensity.small)
                Text("Medium").tag(RowDensity.medium)
                Text("Large").tag(RowDensity.large)
            }
            Divider()
            Toggle("Show Hidden Files", isOn: $settings.showsHiddenFiles)
            Toggle("Show File Extensions", isOn: $settings.showsExtensions)
        } label: {
            Label("View", systemImage: "eye")
        }
        .fixedSize()
    }

    private var sortColumn: Binding<SortColumn> {
        Binding(
            get: { browser.sort.column },
            set: { browser.sort(by: $0, ascending: browser.sort.ascending) })
    }

    private var ascending: Binding<Bool> {
        Binding(
            get: { browser.sort.ascending },
            set: { browser.sort(by: browser.sort.column, ascending: $0) })
    }

    private var showsDetails: Binding<Bool> {
        Binding(
            get: { browser.settings.showsDetails },
            set: { browser.settings.showsDetails = $0 })
    }

    private var viewMode: Binding<ViewMode> {
        Binding(get: { browser.viewMode }, set: { browser.viewMode = $0 })
    }
}
