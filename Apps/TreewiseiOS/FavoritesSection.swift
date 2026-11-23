import SwiftUI
import TreewiseCore
import TreewiseUI

/// The sidebar's Favorites (ADR 0131): folders inside the locations, added with Add to
/// Favorites or by dragging a folder between the rows, put in order by dragging, removed
/// with a swipe or the menu. A drop on a favorite moves or copies into its folder. A
/// favorite whose folder cannot be reached shows greyed, to remove.
struct FavoritesSection: View {
    let browser: BrowserState
    let drops: ItemDrops

    var body: some View {
        Section {
            ForEach(browser.favorites) { folder in
                Label(folder.name, systemImage: ItemSymbol.name(for: folder))
                    .tag(folder.id)
                    .contextMenu { removeButton(folder.id) }
                    .swipeActions { swipeRemoveButton(folder.id) }
                    .takesDrops(on: folder, with: drops)
            }
            .onMove(perform: move)
            .onInsert(of: [.treewiseItem], perform: insert)
            ForEach(browser.unreachableFavorites, id: \.self) { folder in
                Label(Self.name(of: folder), systemImage: "folder.badge.questionmark")
                    .foregroundStyle(.secondary)
                    .accessibilityHint(Text("Not available."))
                    .contextMenu { removeButton(folder) }
                    .swipeActions { swipeRemoveButton(folder) }
            }
        } header: {
            Text("Favorites")
        } footer: {
            if browser.favorites.isEmpty, browser.unreachableFavorites.isEmpty {
                Text("Add a folder with Add to Favorites in its menu, or drag it here.")
            }
        }
    }

    /// A favorite's name from its path, while its folder cannot be read.
    private static func name(of folder: FileItem.ID) -> String {
        URL(fileURLWithPath: folder.rawValue).lastPathComponent
    }

    private func removeButton(_ folder: FileItem.ID) -> some View {
        Button(role: .destructive) {
            Task { await browser.removeFavorite(folder) }
        } label: {
            Label("Remove from Favorites", systemImage: "star.slash")
        }
    }

    /// Remove from Favorites as a swipe shows it: red, but without the destructive role, with
    /// which SwiftUI takes the row away itself on a full swipe, before the favorites change.
    /// After the sidebar was built again under the document picker, that left SwiftUI's list
    /// deleting the row twice, which ended the app (iOS 27).
    private func swipeRemoveButton(_ folder: FileItem.ID) -> some View {
        Button {
            Task { await browser.removeFavorite(folder) }
        } label: {
            Label("Remove from Favorites", systemImage: "star.slash")
        }
        .tint(.red)
    }

    private func move(_ source: IndexSet, to destination: Int) {
        let rows = browser.favorites
        guard let moved = source.first.map({ rows[$0].id }) else { return }
        let next = destination < rows.count ? rows[destination].id : nil
        Task { await browser.moveFavorite(moved, before: next) }
    }

    /// Adds the folders dragged between the rows, before the row they land on.
    private func insert(at index: Int, _ providers: [NSItemProvider]) {
        let rows = browser.favorites
        let next = index < rows.count ? rows[index].id : nil
        Task {
            for provider in providers {
                guard let dragged = await DraggedItem.load(from: provider) else { continue }
                await browser.addFavorite(FileItem.ID(dragged.path), before: next)
            }
        }
    }
}
