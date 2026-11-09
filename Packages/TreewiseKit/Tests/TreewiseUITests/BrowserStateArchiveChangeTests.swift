import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Changing an archive from the window (ADR 0078).
@MainActor
@Suite struct BrowserStateArchiveChangeTests {
    private static let top = ArchivePath(archive: "/docs/Photos.zip")
    private static let inner = top.child("2024")
    private static let photo = inner.child("beach.jpg")

    let fileSystem = ChangingFileSystem()

    private func browser(at folder: FileItem.ID) async throws -> BrowserState {
        let volume = try await fileSystem.item(at: "documents").volume
        fileSystem.add(FileItem(id: "/docs", name: "docs", kind: .folder, volume: volume))
        fileSystem.add(entry("/docs/Photos.zip", parent: "/docs", kind: .file, volume: volume))
        fileSystem.add(entry("/docs/note.txt", parent: "/docs", kind: .file, volume: volume))
        for (id, parent, kind) in [
            (Self.top.id, "/docs/Photos.zip" as FileItem.ID, ItemKind.folder),
            (Self.inner.id, Self.top.id, .folder),
            (Self.top.child("Other").id, Self.top.id, .folder),
            (Self.photo.id, Self.inner.id, .file),
        ] {
            fileSystem.add(entry(id, parent: parent, kind: kind, volume: Self.top.volume))
        }
        return await makeBrowser(fileSystem: fileSystem, at: folder)
    }

    private func entry(
        _ id: FileItem.ID, parent: FileItem.ID, kind: ItemKind, volume: VolumeID
    ) -> FileItem {
        let name =
            ArchivePath(id).map(\.name) ?? String(id.rawValue.split(separator: "/").last ?? "")
        return FileItem(id: id, name: name, kind: kind, parentID: parent, volume: volume)
    }

    private func select(_ ids: Set<FileItem.ID>, in browser: BrowserState) {
        browser.setSelection(ids, in: browser.layout.focusedPane.activeTabID)
    }

    @Test func pastingAFileAddsItToTheArchive() async throws {
        let browser = try await browser(at: "/docs")
        select(["/docs/note.txt"], in: browser)
        browser.copySelection()

        await browser.navigate(pane: 0, to: Self.inner.id)
        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(
            fileSystem.appliedEdits == [
                .add([
                    ArchiveAddition(
                        source: URL(fileURLWithPath: "/docs/note.txt"), path: "2024/note.txt")
                ])
            ])
    }

    @Test func aNameThatIsTakenCanBeKeptBesideIt() async throws {
        let browser = try await browser(at: "/docs")
        fileSystem.add(
            entry(
                Self.inner.child("note.txt").id, parent: Self.inner.id, kind: .file,
                volume: Self.top.volume))
        select(["/docs/note.txt"], in: browser)
        browser.copySelection()

        await browser.navigate(pane: 0, to: Self.inner.id)
        await browser.paste(resolver: ScriptedResolver(.keepBoth), undoManager: nil)

        #expect(
            fileSystem.appliedEdits == [
                .add([
                    ArchiveAddition(
                        source: URL(fileURLWithPath: "/docs/note.txt"),
                        path: "2024/note copy.txt")
                ])
            ])
    }

    @Test func stoppingAtANameThatIsTakenChangesNothing() async throws {
        let browser = try await browser(at: "/docs")
        fileSystem.add(
            entry(
                Self.inner.child("note.txt").id, parent: Self.inner.id, kind: .file,
                volume: Self.top.volume))
        select(["/docs/note.txt"], in: browser)
        browser.copySelection()

        await browser.navigate(pane: 0, to: Self.inner.id)
        await browser.paste(resolver: ScriptedResolver(.stop), undoManager: nil)

        #expect(fileSystem.appliedEdits.isEmpty)
        #expect(browser.failure == nil)
    }

    @Test func aCutEntryMovesWithinItsArchive() async throws {
        let browser = try await browser(at: Self.inner.id)
        select([Self.photo.id], in: browser)
        browser.cutSelection()

        await browser.navigate(pane: 0, to: Self.top.child("Other").id)
        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(
            fileSystem.appliedEdits == [.relocate(from: "2024/beach.jpg", to: "Other/beach.jpg")])
        #expect(browser.clipboard == nil)
    }

    @Test func aCopiedEntryComesFromItsCopyWithinItsArchive() async throws {
        let browser = try await browser(at: Self.inner.id)
        select([Self.photo.id], in: browser)
        browser.copySelection()

        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(
            fileSystem.appliedEdits == [
                .add([
                    ArchiveAddition(
                        source: URL(fileURLWithPath: "/cache/beach.jpg"),
                        path: "2024/beach copy.jpg")
                ])
            ])
    }

    @Test func aCutEntryPastedOutsideIsCopied() async throws {
        let browser = try await browser(at: Self.inner.id)
        select([Self.photo.id], in: browser)
        browser.cutSelection()

        await browser.navigate(pane: 0, to: "/docs")
        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(browser.focusedNames.contains("beach.jpg"))
        #expect(fileSystem.appliedEdits.isEmpty)
        #expect(browser.failure == nil)
    }

    @Test func renamingChangesTheEntry() async throws {
        let browser = try await browser(at: Self.inner.id)
        let photo = try await fileSystem.item(at: Self.photo.id)

        await browser.rename(photo, to: "sea.jpg", undoManager: nil)

        #expect(
            fileSystem.appliedEdits == [.relocate(from: "2024/beach.jpg", to: "2024/sea.jpg")])
    }

    @Test func aNameThatCannotBeUsedChangesNothing() async throws {
        let browser = try await browser(at: Self.inner.id)
        let photo = try await fileSystem.item(at: Self.photo.id)

        await browser.rename(photo, to: "a/b.jpg", undoManager: nil)

        #expect(fileSystem.appliedEdits.isEmpty)
        #expect(browser.failure == .invalidName("a/b.jpg"))
    }

    @Test func aNewFolderGoesInTheFolderShown() async throws {
        let browser = try await browser(at: Self.inner.id)

        _ = await browser.newFolder(undoManager: nil, locale: Locale(identifier: "en"))

        #expect(fileSystem.appliedEdits == [.newFolder("2024/untitled folder")])
    }

    @Test func deletingRemovesEntriesInOneChange() async throws {
        let browser = try await browser(at: Self.top.id)
        select([Self.inner.id, Self.top.child("Other").id], in: browser)

        await browser.moveSelectionToTrash(undoManager: nil)

        #expect(fileSystem.appliedEdits.count == 1)
        guard case .remove(let paths)? = fileSystem.appliedEdits.first else {
            Issue.record("the entries are removed")
            return
        }
        #expect(Set(paths) == ["2024", "Other"])
    }

    @Test func insideAZipNothingIsCompressedOrNamed() async throws {
        let browser = try await browser(at: Self.inner.id)
        select([Self.photo.id], in: browser)

        #expect(browser.canAddItems)
        #expect(browser.canRenameSelection)
        #expect(browser.canTrashSelection)
        #expect(!browser.canCompressSelection)
        #expect(!browser.canSuggestNames)
    }
}
