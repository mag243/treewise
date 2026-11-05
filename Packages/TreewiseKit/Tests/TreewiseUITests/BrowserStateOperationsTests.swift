import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Operations from the window: paste, new folder, rename, Trash, drop, undo
/// (PLAN.md §9.4, ADR 0018).
@MainActor
@Suite struct BrowserStateOperationsTests {
    let fileSystem = ChangingFileSystem()

    private func browser(at folder: FileItem.ID = "documents") async -> BrowserState {
        await makeBrowser(fileSystem: fileSystem, at: folder)
    }

    private var tab: (BrowserState) -> TabModel.ID { { $0.layout.focusedPane.activeTabID } }

    @Test func cutsAndPastesIntoTheFocusedPane() async throws {
        let browser = await browser()
        browser.setSelection(["doc2"], in: tab(browser))
        browser.cutSelection()
        #expect(browser.clipboard?.isCut("doc2") == true)

        await browser.toggleSplit(newPaneAt: "projects")
        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(browser.focusedNames.contains("Notes.md"))
        #expect(browser.clipboard == nil)
        #expect(browser.content(of: tab(browser)).selection.count == 1)
        #expect(
            !browser.visibleItems(of: browser.layout.panes[0].activeTabID).contains {
                $0.name == "Notes.md"
            })
    }

    @Test func cutsInOneWindowAndPastesInAnother() async throws {
        let clipboard = SharedClipboard()
        let left = BrowserState(
            fileSystem: fileSystem, watcher: ManualFolderWatcher(), startFolder: "documents",
            clipboard: clipboard)
        let right = BrowserState(
            fileSystem: fileSystem, watcher: ManualFolderWatcher(), startFolder: "projects",
            clipboard: clipboard)
        await left.start()
        await right.start()
        left.setSelection(["doc2"], in: tab(left))
        left.cutSelection()
        #expect(right.clipboard?.isCut("doc2") == true, "the other window sees the cut item")

        await right.paste(resolver: ScriptedResolver(), undoManager: nil)

        #expect(right.focusedNames.contains("Notes.md"))
        #expect(left.clipboard == nil, "pasting the cut item empties the clipboard everywhere")
    }

    @Test func keepsTheClipboardAfterPastingACopy() async {
        let browser = await browser()
        browser.setSelection(["doc2"], in: tab(browser))
        browser.copySelection()
        await browser.navigate(pane: 0, to: "projects")
        await browser.paste(resolver: ScriptedResolver(), undoManager: nil)
        await browser.paste(resolver: ScriptedResolver(.keepBoth), undoManager: nil)

        #expect(
            browser.focusedNames.filter { $0.hasPrefix("Notes") } == ["Notes copy.md", "Notes.md"])
        #expect(browser.clipboard != nil)
    }

    @Test func createsAFolderInTheFocusedPaneAndSelectsIt() async throws {
        let browser = await browser()
        let created = try #require(
            await browser.newFolder(undoManager: nil, locale: Locale(identifier: "en")))
        #expect(created.name == "untitled folder")
        #expect(browser.content(of: tab(browser)).selection == [created.id])
    }

    @Test func renamesAnItem() async throws {
        let browser = await browser()
        let notes = try await fileSystem.item(at: "doc2")
        await browser.rename(notes, to: "Ideas.md", undoManager: nil)
        #expect(browser.focusedNames.contains("Ideas.md"))
        #expect(browser.failure == nil)
    }

    @Test func reportsARenameThatIsNotAllowed() async throws {
        let browser = await browser()
        let notes = try await fileSystem.item(at: "doc2")
        await browser.rename(notes, to: "a/b", undoManager: nil)
        #expect(browser.failure == .invalidName("a/b"))
    }

    @Test func movesTheSelectionToTheTrashAndForgetsItOnTheClipboard() async {
        let browser = await browser()
        browser.setSelection(["doc2"], in: tab(browser))
        browser.copySelection()
        await browser.moveSelectionToTrash(undoManager: nil)
        #expect(!browser.focusedNames.contains("Notes.md"))
        #expect(browser.clipboard == nil)
    }

    @Test func movesAnotherTabToTheParentWhenItsFolderGoesToTheTrash() async {
        let browser = await browser()
        await browser.openTab(pane: 0, at: "invoices")
        await browser.activateTab(pane: 0, tab: browser.layout.focusedPane.tabs[0].id)
        browser.setSelection(["invoices"], in: tab(browser))

        await browser.moveSelectionToTrash(undoManager: nil)

        #expect(browser.layout.focusedPane.tabs[1].folder == "documents")
    }

    @Test func dropsItemsOnAFolderWithThePlannedMode() async throws {
        let browser = await browser()
        let notes = try await fileSystem.item(at: "doc2")
        let backups = try await fileSystem.item(at: "backups")
        await browser.drop(
            [notes], onto: backups, modifiers: [], resolver: ScriptedResolver(), undoManager: nil)
        #expect(try await fileSystem.contents(of: "backups").contains { $0.name == "Notes.md" })
        #expect(browser.focusedNames.contains("Notes.md"), "a cross-volume drop copies")
    }

    @Test func copiesTheSelectionToAnotherWindowsFolder() async throws {
        let browser = await browser()
        browser.setSelection(["doc2"], in: tab(browser))
        await browser.send(
            selectionTo: "projects", mode: .copy, resolver: ScriptedResolver(), undoManager: nil)
        #expect(try await fileSystem.contents(of: "projects").contains { $0.name == "Notes.md" })
        #expect(browser.focusedNames.contains("Notes.md"), "a copy leaves the original")
    }

    @Test func movesTheSelectionToAnotherWindowsFolder() async throws {
        let browser = await browser()
        browser.setSelection(["doc2"], in: tab(browser))
        await browser.send(
            selectionTo: "projects", mode: .move, resolver: ScriptedResolver(), undoManager: nil)
        #expect(try await fileSystem.contents(of: "projects").contains { $0.name == "Notes.md" })
        #expect(
            await eventually { !browser.focusedNames.contains("Notes.md") },
            "a move takes it away")
    }

    @Test func undoesAndRedoesAMove() async throws {
        let browser = await browser()
        let undoManager = UndoManager()
        let notes = try await fileSystem.item(at: "doc2")
        let projects = try await fileSystem.item(at: "projects")
        await browser.drop(
            [notes], onto: projects, modifiers: [], resolver: ScriptedResolver(),
            undoManager: undoManager)
        #expect(!browser.focusedNames.contains("Notes.md"))
        #expect(undoManager.undoActionName == "Move")

        undoManager.undo()
        #expect(await eventually { browser.focusedNames.contains("Notes.md") })
        undoManager.redo()
        #expect(await eventually { !browser.focusedNames.contains("Notes.md") })
    }

    @Test func asksTheListToRenameANewFolder() async throws {
        let browser = await browser()
        let created = try #require(
            await browser.newFolder(undoManager: nil, locale: Locale(identifier: "en")))
        #expect(browser.renameRequest == created.id)
        browser.renameRequest = nil
        #expect(browser.renameRequest == nil)
    }

    @Test func clearsAFailureOnceShown() async throws {
        let browser = await browser()
        await browser.rename(try await fileSystem.item(at: "doc2"), to: "a/b", undoManager: nil)
        browser.clearFailure()
        #expect(browser.failure == nil)
    }

    @Test func pastesItemsFromOutsideAsCopies() async throws {
        let browser = await browser(at: "projects")
        let notes = try await fileSystem.item(at: "doc2")
        await browser.pasteItems([notes], resolver: ScriptedResolver(), undoManager: nil)
        #expect(browser.focusedNames.contains("Notes.md"))
        #expect(try await fileSystem.contents(of: "documents").contains { $0.name == "Notes.md" })
    }

    @Test func reportsAFailureThatIsNoFileSystemError() async throws {
        let browser = await browser(at: "projects")
        let notes = try await fileSystem.item(at: "doc2")
        let failure = CocoaError(.fileWriteUnknown)
        fileSystem.failChanges(with: failure)

        await browser.pasteItems([notes], resolver: ScriptedResolver(), undoManager: nil)

        #expect(browser.failure == .unexpected(failure.localizedDescription))
    }

    @Test func cancelsARunningTransferAndHidesItsProgress() async throws {
        let browser = await browser(at: "projects")
        let notes = try await fileSystem.item(at: "doc2")
        fileSystem.holdChanges()
        let paste = Task {
            await browser.pasteItems([notes], resolver: ScriptedResolver(), undoManager: nil)
        }
        #expect(await eventually { browser.progress != nil })

        browser.cancelOperation()
        fileSystem.releaseChanges()
        await paste.value

        #expect(!browser.focusedNames.contains("Notes.md"))
        #expect(browser.progress == nil)
        #expect(browser.failure == nil)
    }

    @Test func movesCopiedItemsHereAndEmptiesTheClipboard() async throws {
        let browser = await browser()
        browser.setSelection(["doc2"], in: tab(browser))
        browser.copySelection()
        await browser.toggleSplit(newPaneAt: "projects")

        await browser.moveHere(resolver: ScriptedResolver(), undoManager: nil)

        #expect(browser.focusedNames.contains("Notes.md"))
        #expect(try await !fileSystem.contents(of: "documents").contains { $0.name == "Notes.md" })
        #expect(browser.clipboard == nil)
    }

    @Test func leavesHiddenItemsOutUnlessTheSettingShowsThem() async {
        fileSystem.add(
            FileItem(
                id: "dotfile", name: ".profile", kind: .file, parentID: "documents",
                volume: "hd", isHidden: true))
        let settings = BrowserSettings(store: MemorySettingsStore())
        let browser = await makeBrowser(fileSystem: fileSystem, settings: settings)
        #expect(!browser.focusedNames.contains(".profile"))

        settings.showsHiddenFiles = true
        #expect(browser.focusedNames.contains(".profile"))
    }

    @Test func leavesHiddenFoldersOutOfTheSidebar() async {
        fileSystem.add(
            FileItem(
                id: "dotfolder", name: ".cache", kind: .folder, parentID: "documents",
                volume: "hd", isHidden: true))
        let browser = await browser()
        #expect(!(await browser.subfolders(of: "documents")).contains { $0.name == ".cache" })
    }

    @Test func pausesAndResumesATransfer() async throws {
        let browser = await browser(at: "projects")
        let notes = try await fileSystem.item(at: "doc2")
        fileSystem.holdChanges()
        let paste = Task {
            await browser.pasteItems([notes], resolver: ScriptedResolver(), undoManager: nil)
        }
        #expect(await eventually { browser.progress != nil })

        browser.pauseOperation()
        fileSystem.releaseChanges()
        #expect(browser.isPaused)
        #expect(!(await eventually { browser.focusedNames.contains("Notes.md") }))

        browser.resumeOperation()
        await paste.value
        #expect(!browser.isPaused)
        #expect(browser.focusedNames.contains("Notes.md"))
    }
}
