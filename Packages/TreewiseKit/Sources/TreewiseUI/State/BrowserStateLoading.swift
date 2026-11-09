import TreewiseCore

extension BrowserState {
    /// The watch on the folder an active tab shows.
    struct Watch {
        let folder: FileItem.ID
        let task: Task<Void, Never>
    }

    /// Reads the folder a tab shows. When the folder is gone, the tab moves to
    /// the nearest folder that is left. Results for a folder the tab has left
    /// in the meantime are dropped.
    func load(_ tab: TabModel.ID) async {
        guard let folder = layout.tab(tab)?.folder else { return }
        releaseArchivesNoLongerShown()
        do {
            let items = try await fileSystem.contents(of: folder)
            let folderItem = try? await fileSystem.item(at: folder)
            let ancestry = (try? await fileSystem.ancestorIDs(of: folder)) ?? []
            let capacity = try? await fileSystem.availableCapacity(of: folder)
            guard layout.tab(tab)?.folder == folder else { return }
            var content = content(of: tab)
            let present = Set(items.map(\.id))
            content.folder = folderItem
            content.items = items
            content.selection = content.selection.intersection(present)
            content.failure = nil
            content.ancestry = ancestry
            content.availableCapacity = capacity
            contents[tab] = content
        } catch {
            guard layout.tab(tab)?.folder == folder else { return }
            await recover(tab, folder: folder, from: error)
        }
        updateWatches()
    }

    /// Lets go of what is kept of archives no tab shows any more, also of a
    /// listing that is still being read (ADR 0076).
    private func releaseArchivesNoLongerShown() {
        let shown = Set(layout.panes.flatMap(\.tabs).compactMap { ArchivePath($0.folder)?.archive })
        let archives = archives
        for archive in shownArchives.subtracting(shown) {
            Task { await archives?.releaseCache(of: archive) }
        }
        shownArchives = shown
    }

    /// Watches exactly the folders the panes' active tabs show.
    func updateWatches() {
        releaseArchivesNoLongerShown()
        let shown = Dictionary(
            layout.panes.map { ($0.activeTabID, $0.activeTab.folder) }
        ) { first, _ in first }
        for (tab, watch) in watches where shown[tab] != watch.folder {
            watch.task.cancel()
            watches[tab] = nil
        }
        for (tab, folder) in shown where watches[tab] == nil {
            let changes = watcher.changes(of: folder)
            let task = Task { [weak self] in
                for await _ in changes {
                    await self?.load(tab)
                }
            }
            watches[tab] = Watch(folder: folder, task: task)
        }
    }

    private func recover(_ tab: TabModel.ID, folder: FileItem.ID, from error: any Error) async {
        let failure = error as? FileSystemError
        let ancestry = content(of: tab).ancestry
        if case .notFound = failure, let index = await firstExisting(in: ancestry) {
            let removed = Set([folder] + ancestry[..<index])
            layout.updateTab(tab) { $0.history.removeItems(removed, fallback: ancestry[index]) }
            contents[tab] = TabContent()
            await load(tab)
            return
        }
        var content = TabContent()
        content.query = self.content(of: tab).query
        content.failure = failure
        contents[tab] = content
    }

    private func firstExisting(in ancestry: [FileItem.ID]) async -> Int? {
        for (index, id) in ancestry.enumerated() where (try? await fileSystem.item(at: id)) != nil {
            return index
        }
        return nil
    }
}

extension BrowserState {
    /// Reads the Locations again whenever a volume is mounted or ejected,
    /// which the watcher reports as a change of This Mac (ADR 0044).
    func watchLocations() {
        guard locationsWatch == nil else { return }
        let changes = watcher.changes(of: .computer)
        locationsWatch = Task { [weak self] in
            for await _ in changes {
                guard let self else { return }
                locations = (try? await fileSystem.locations()) ?? []
                await reloadFavorites()
            }
        }
    }
}
