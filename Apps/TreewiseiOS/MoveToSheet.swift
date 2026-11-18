import SwiftUI
import TreewiseCore
import TreewiseUI

/// What Move to… or Copy to… is asked for: the items, and whether they move or copy.
struct MoveToRequest: Identifiable {
    enum Purpose {
        case move
        case copy
    }

    let id = UUID()
    let items: [FileItem]
    let purpose: Purpose
}

/// Move to… and Copy to… where the width is compact, as the iPhone shows no second folder
/// (ADR 0132): the recent folders, the favorites and the locations, a tap going into a
/// folder, and Move or Copy into the folder shown, through the drag rules as a drop with ⌘
/// or ⌥ would.
struct MoveToSheet: View {
    let request: MoveToRequest
    let browser: BrowserState
    let drops: ItemDrops
    @Environment(\.dismiss) private var dismiss
    /// The folders gone into, the last of them the target.
    @State private var path: [FileItem] = []
    /// The folders the tab showed before, the last first (ADR 0132).
    @State private var recent: [FileItem] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !recent.isEmpty {
                    Section("Recent") {
                        ForEach(recent) { folder in
                            folderLink(folder)
                                // The UI tests find it by it.
                                .accessibilityIdentifier("recent-\(folder.name)")
                        }
                    }
                }
                if !browser.favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(browser.favorites) { folderLink($0) }
                    }
                }
                Section("Locations") {
                    ForEach(browser.locations) { folderLink($0) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .task { recent = await browser.recentFolders() }
            .navigationDestination(for: FileItem.self) { folder in
                MoveToFolderList(folder: folder, browser: browser)
                    .toolbar { toolbar }
            }
        }
    }

    private var title: String {
        switch request.purpose {
        case .move: String(localized: "Move to Folder")
        case .copy: String(localized: "Copy to Folder")
        }
    }

    private func folderLink(_ folder: FileItem) -> some View {
        NavigationLink(value: folder) {
            Label(folder.name, systemImage: ItemSymbol.name(for: folder))
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(request.purpose == .move ? "Move" : "Copy") {
                guard let target = path.last else { return }
                let modifiers: DropModifiers = request.purpose == .move ? .command : .option
                drops.land(request.items, on: target, modifiers: modifiers)
                dismiss()
            }
            .disabled(path.isEmpty)
            // The UI tests find it by it.
            .accessibilityIdentifier("moveToConfirm")
        }
    }
}

/// A folder's subfolders in Move to…, read as it shows.
private struct MoveToFolderList: View {
    let folder: FileItem
    let browser: BrowserState
    @State private var subfolders: [FileItem]?

    var body: some View {
        List {
            if let subfolders {
                ForEach(subfolders) { subfolder in
                    NavigationLink(value: subfolder) {
                        Label(subfolder.name, systemImage: ItemSymbol.name(for: subfolder))
                    }
                }
            }
        }
        .overlay {
            if subfolders == nil {
                ProgressView()
            } else if subfolders?.isEmpty == true {
                ContentUnavailableView("No Folders", systemImage: "folder")
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { subfolders = await browser.subfolders(of: folder.id) }
    }
}
