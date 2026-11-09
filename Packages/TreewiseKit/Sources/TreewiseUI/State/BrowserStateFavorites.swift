import TreewiseCore

/// The Favorites the user chooses (ADR 0050). The list lives in the settings
/// all windows share; `favorites` holds the rows of the folders that are there.
extension BrowserState {
    /// Whether a folder is among the rows of Favorites.
    public func isFavorite(_ folder: FileItem.ID) -> Bool {
        favorites.contains { $0.id == folder }
    }

    /// Adds a folder before `next`, or at the end. Only what opens like a
    /// folder can be a favorite, and This Mac cannot.
    public func addFavorite(_ folder: FileItem.ID, before next: FileItem.ID? = nil) async {
        guard folder != .computer, !folder.isInsideArchive,
            let item = try? await fileSystem.item(at: folder),
            item.isContainer
        else { return }
        await changeFavorites { $0.add(folder, before: next) }
    }

    /// Removes a favorite; the folder itself is not touched.
    public func removeFavorite(_ folder: FileItem.ID) async {
        await changeFavorites { $0.remove(folder) }
    }

    /// Moves a favorite before `next`, or to the end.
    public func moveFavorite(_ folder: FileItem.ID, before next: FileItem.ID?) async {
        await changeFavorites { $0.move(folder, before: next) }
    }

    /// Goes back to the built-in favorites.
    public func restoreDefaultFavorites() async {
        settings.favoriteFolders = nil
        await reloadFavorites()
    }

    /// Reads the rows of Favorites again: the built-in ones until the user
    /// changed the list, then the folders of the list that are there.
    public func reloadFavorites() async {
        guard let folders = settings.favoriteFolders else {
            favorites = (try? await fileSystem.favorites()) ?? []
            return
        }
        var rows: [FileItem] = []
        for folder in folders {
            if let item = try? await fileSystem.item(at: folder), item.isContainer {
                rows.append(item)
            }
        }
        favorites = rows
    }

    /// Lets the favorites follow folders that were renamed or moved.
    func relocateFavorites(_ moves: [(old: FileItem.ID, new: FileItem.ID)]) async {
        await changeFavorites { list in
            for move in moves where move.old != move.new {
                list.relocate(move.old, to: move.new)
            }
        }
    }

    /// Applies a change; the first one that changes anything stores the whole
    /// list, so the built-in favorites stay in use until then.
    private func changeFavorites(_ change: (inout FavoriteList) -> Void) async {
        let current =
            if let folders = settings.favoriteFolders {
                folders
            } else {
                ((try? await fileSystem.favorites()) ?? []).map(\.id)
            }
        var list = FavoriteList(folders: current)
        change(&list)
        guard list.folders != current else { return }
        settings.favoriteFolders = list.folders
        await reloadFavorites()
    }
}
