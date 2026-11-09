import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// A review opened from a window (ADR 0057).
@MainActor
@Suite struct BrowserStateNameReviewTests {
    private let fileSystem = ChangingFileSystem()
    private let host = ScriptedModuleHost(modules: [], answers: [:])

    @Test func reviewsTheFolderWithoutASelection() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        let review = await browser.makeNameReview(host: host, store: MemoryFolderSettings())
        #expect(review?.scope == .wholeFolder)
        #expect(review?.folder.id == "documents")
    }

    @Test func aSelectionReviewsOnlyTheSelection() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        browser.setSelection(["doc2"], in: browser.layout.focusedPane.activeTabID)
        let review = await browser.makeNameReview(host: host, store: MemoryFolderSettings())
        #expect(review?.scope == .selection)
    }

    @Test func theWholeFolderIsReviewedDespiteASelection() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        browser.setSelection(["doc2"], in: browser.layout.focusedPane.activeTabID)
        let review = await browser.makeFolderNameReview(host: host, store: MemoryFolderSettings())
        #expect(review?.scope == .wholeFolder)
        #expect(review?.folder.id == "documents")
    }

    @Test func proposesForOneFileBeingRenamed() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        let parent = try await fileSystem.item(at: "documents")
        let item = FileItem(
            id: "documents/a", name: "a.txt", kind: .file, parentID: parent.id,
            volume: parent.volume)
        fileSystem.add(item)
        let proposals = await browser.makeNameProposals(
            for: item, host: host, store: MemoryFolderSettings())
        #expect(proposals?.scope == .selection)
        await proposals?.start()
        #expect(proposals?.session?.entries.map(\.id) == [item.id])
    }

    @Test func proposesNothingForAFolderBeingRenamed() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        let folder = try await fileSystem.item(at: "documents")
        #expect(!browser.canSuggestName(for: folder))
    }

    @Test func offersSuggestionsWhereItemsCanBeAdded() async {
        #expect(await makeBrowser(fileSystem: fileSystem).canSuggestNames)
    }

    @Test func aFileSystemThatCannotChangeOffersNone() async {
        let browser = await makeBrowser(fileSystem: Fixture.standard)
        #expect(!browser.canSuggestNames)
        #expect(await browser.makeNameReview(host: host, store: MemoryFolderSettings()) == nil)
    }

    @Test func registersOneUndoForARename() async throws {
        let browser = await makeBrowser(fileSystem: fileSystem)
        let parent = try await fileSystem.item(at: "documents")
        let item = FileItem(
            id: "documents/a", name: "a.txt", kind: .file, parentID: parent.id,
            volume: parent.volume)
        fileSystem.add(item)
        let manager = UndoManager()
        manager.groupsByEvent = false
        manager.beginUndoGrouping()
        let outcome = await fileSystem.applyBatch([
            BatchRenameStep(item: item.id, from: "a.txt", to: "b.txt")
        ])
        await browser.finishNameReview(outcome, undoManager: manager)
        manager.endUndoGrouping()
        #expect(manager.canUndo)
        #expect(try await fileSystem.item(at: item.id).name == "b.txt")
    }
}

/// A review asks paid modules with the window's licences (ADR 0071).
@MainActor
@Suite struct BrowserStateLicenceTests {
    private let fileSystem = ChangingFileSystem()
    private static let paid = NameModuleDescription(
        id: "paid", contentTypes: ["public.item"], neededContent: [], fields: [],
        defaultTemplate: "{folder}")

    @Test func asksWithTheKeysAndStartsTheTrial() async throws {
        let host = ScriptedModuleHost(modules: [Self.paid], answers: [:])
        host.setLicenceState(.trial(daysLeft: 14), for: "paid")
        let browser = await makeBrowser(fileSystem: fileSystem)
        let secure = MemorySecureStore()
        browser.licences = LicenceKeeper(settings: browser.settings, secure: secure)
        browser.licences?.add(key: "TW1-abc.def")
        let review = await browser.makeNameReview(host: host, store: MemoryFolderSettings())
        await review?.start()
        #expect(host.licenceKeys.last == ["TW1-abc.def"])
        #expect(secure.value(for: LicenceKeeper.trialStartKey) != nil, "the trial started")
    }
}
