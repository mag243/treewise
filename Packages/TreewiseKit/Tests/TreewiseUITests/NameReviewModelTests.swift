import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// The review overview's state, with scripted modules (ADR 0057).
@MainActor
@Suite struct NameReviewModelTests {
    static let free = NameModuleDescription.defaultModuleID
    static let paid = "paid"
    static let freeDescription = NameModuleDescription(
        id: free, contentTypes: ["public.item"], neededContent: [],
        fields: [
            .init(name: "date", kind: .date), .init(name: "text", kind: .text),
            .init(name: "number", kind: .number),
        ], defaultTemplate: "Doc {text}")
    static let paidDescription = NameModuleDescription(
        id: paid, contentTypes: ["com.adobe.pdf"], neededContent: [.text],
        fields: [.init(name: "company", kind: .text)], defaultTemplate: "Co {company}")

    let fileSystem = ChangingFileSystem()
    let store = MemoryFolderSettings()
    let savedPatterns = SavedPatternsBox()
    let folder: FileItem

    init() async throws {
        let parent = try await fileSystem.item(at: "documents")
        folder = FileItem(
            id: "review", name: "Review", kind: .folder, parentID: parent.id, volume: parent.volume)
        fileSystem.add(folder)
    }

    func addFile(_ name: String) -> FileItem {
        let item = FileItem(
            id: FileItem.ID("review/\(name)"), name: name, kind: .file, parentID: folder.id,
            volume: folder.volume)
        fileSystem.add(item)
        return item
    }

    func host(
        modules: [NameModuleDescription] = [freeDescription],
        answers: [String: Result<[[String: NameTemplate.Value]], NameModuleHostError>]? = nil
    ) -> ScriptedModuleHost {
        let host = ScriptedModuleHost(
            modules: modules,
            answers: answers ?? [Self.free: .success([["text": .text("New")]])])
        host.setDerivedTemplate("Doc {text}", for: Self.free)
        return host
    }

    /// The content type a file's extension stands for, as far as these tests need.
    nonisolated static func contentType(of name: String) -> String {
        if name.hasSuffix(".pdf") { return "com.adobe.pdf" }
        if name.hasSuffix(".heic") { return "public.heic" }
        return "public.plain-text"
    }

    func model(
        _ host: ScriptedModuleHost, scope: NameReviewRules.Scope = .wholeFolder,
        selection: [FileItem] = [], suggestedDate: SuggestedDate? = nil,
        personalDataInNames: PersonalDataInNames = .leaveOutOfApproveAll,
        addOns: AddOnPreferences = AddOnPreferences(),
        licence: LicenceContext = .none,
        startTrial: @escaping @MainActor () -> Void = {}
    ) async -> NameReviewModel {
        let patterns = savedPatterns
        let model = NameReviewModel(
            folder: folder, scope: scope, selection: selection,
            dependencies: .init(
                operations: fileSystem, host: host, store: store, defaultPattern: "Std {text}",
                personalDataInNames: personalDataInNames,
                addOns: addOns,
                licence: { licence },
                startTrial: {
                    startTrial()
                    var started = licence
                    started.trialStart = Date()
                    return started
                },
                savedPatterns: { patterns.list },
                savePattern: { patterns.save(name: $0, text: $1) },
                makeRequest: { item, siblings, needed in
                    NameRequest(
                        id: item.id.rawValue, name: item.name,
                        contentType: Self.contentType(of: item.name),
                        byteCount: nil, created: nil, modified: nil, suggestedDate: suggestedDate,
                        siblingNames: siblings.map(\.name),
                        content: needed.contains(.text)
                            ? ModuleContent(text: "contents") : ModuleContent())
                }))
        await model.start()
        await model.waitUntilRead()
        return model
    }

    @Test func proposesANameFromAModulesValues() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        #expect(model.session?.entry(item.id)?.currentName == "Doc New.txt")
        #expect(model.rows.map(\.id) == [item.id])
    }

    @Test func aNewFolderHasOnlyTheFolderPatternModuleOn() async {
        _ = addFile("scan.pdf")
        let model = await model(host(modules: [Self.paidDescription, Self.freeDescription]))
        #expect(model.modules.map(\.isOn) == [false, true])
    }

    @Test func aFirstReviewOpensTheModulesPanel() async {
        _ = addFile("a.txt")
        let model = await model(host())
        #expect(model.isFirstReview)
    }

    @Test func aLaterReviewRemembersTheModules() async {
        _ = addFile("scan.pdf")
        await store.save(
            FolderSettings(enabledModules: [Self.paid], templates: [:]), forFolderAt: "review")
        let host = host(
            modules: [Self.paidDescription, Self.freeDescription],
            answers: [Self.paid: .success([["company": .text("North")]])])
        let model = await model(host)
        #expect(!model.isFirstReview)
        #expect(model.modules.map(\.isOn) == [true, false])
        #expect(host.requests.first?.content.text == "contents")
    }

    @Test func aFileThatFitsIsNotRead() async {
        _ = addFile("Fits.txt")
        let host = host()
        host.setDerivedTemplate("Fits", for: Self.free)
        let model = await model(host)
        #expect(model.rows.isEmpty)
        #expect(model.hiddenRows.count == 1)
        #expect(host.requests.filter { !$0.content.isEmpty }.isEmpty)
    }

    @Test func aSelectionShowsAFileThatFits() async {
        let item = addFile("Fits.txt")
        let host = host()
        host.setDerivedTemplate("Fits", for: Self.free)
        let model = await model(host, scope: .selection, selection: [item])
        #expect(model.rows.map(\.id) == [item.id])
    }

    @Test func aWholeFolderLeavesSubfoldersOut() async {
        fileSystem.add(
            FileItem(
                id: "review/sub", name: "sub", kind: .folder, parentID: folder.id,
                volume: folder.volume))
        let model = await model(host())
        #expect(model.session?.entries.isEmpty == true)
    }

    @Test func turningOnAModuleAsksIt() async {
        let item = addFile("scan.pdf")
        let host = host(
            modules: [Self.paidDescription, Self.freeDescription],
            answers: [
                Self.free: .success([["text": .text("Free")]]),
                Self.paid: .success([["company": .text("North")]]),
            ])
        let model = await model(host)
        await model.setModule(Self.paid, on: true)
        await model.waitUntilRead()
        #expect(
            model.session?.entry(item.id)?.proposals.map(\.name) == [
                "Co North.pdf", "Doc Free.pdf",
            ])
        #expect(
            await store.settings(forFolderAt: "review")?.enabledModules == [Self.paid, Self.free])
    }

    @Test func turningOffAModuleRemovesItsOptions() async {
        let item = addFile("scan.pdf")
        await store.save(
            FolderSettings(enabledModules: [Self.paid, Self.free], templates: [:]),
            forFolderAt: "review")
        let model = await model(
            host(
                modules: [Self.paidDescription, Self.freeDescription],
                answers: [
                    Self.free: .success([["text": .text("Free")]]),
                    Self.paid: .success([["company": .text("North")]]),
                ]))
        await model.setModule(Self.paid, on: false)
        #expect(model.session?.entry(item.id)?.proposals.map(\.name) == ["Doc Free.pdf"])
    }

    @Test func theLastModuleStaysOn() async {
        _ = addFile("a.txt")
        let model = await model(host())
        await model.setModule(Self.free, on: false)
        #expect(model.modules.first?.isOn == true)
    }

    @Test func aFileNoModuleHandlesIsOutOfScope() async {
        let item = addFile("notes.txt")
        await store.save(
            FolderSettings(enabledModules: [Self.paid], templates: [:]), forFolderAt: "review")
        let model = await model(host(modules: [Self.paidDescription]))
        #expect(model.session?.entry(item.id)?.isOutOfScope == true)
    }

    @Test func changingATemplateUpdatesNamesWithoutAskingAgain() async {
        let item = addFile("scan.txt")
        let host = host()
        let model = await model(host)
        let asked = host.requests.count
        await model.setTemplate(Self.free, to: "File {text}")
        #expect(model.session?.entry(item.id)?.currentName == "File New.txt")
        #expect(host.requests.count == asked)
        #expect(model.modules.first?.origin == .user)
        #expect(await store.settings(forFolderAt: "review")?.templates[Self.free] == "File {text}")
    }

    @Test func anUnusableTemplateIsRefusedAndTheLastStays() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        await model.setTemplate(Self.free, to: "{company}")
        #expect(model.modules.first?.templateProblem == .unknownField("company"))
        #expect(model.session?.entry(item.id)?.currentName == "Doc New.txt")
    }

    @Test func aChangedTemplateChangesWhatFits() async {
        _ = addFile("Fits.txt")
        let model = await model(host())
        #expect(model.rows.count == 1)
        await model.setTemplate(Self.free, to: "Fits")
        #expect(model.rows.isEmpty)
    }

    @Test func resettingATemplateAsksForTheDerivedOneAgain() async {
        _ = addFile("scan.txt")
        let host = host()
        host.setDerivedTemplate("Scan {text}", for: Self.free)
        let model = await model(host)
        await model.setTemplate(Self.free, to: "File {text}")
        await model.resetTemplate(Self.free)
        #expect(model.modules.first?.templateText == "Scan {text}")
        #expect(model.modules.first?.origin == .derived)
    }
}

/// The user's saved patterns for a test: `Doc {text}`, the default, and `Co {company}`.
final class SavedPatternsBox: Sendable {
    private let state: Mutex<SavedPatterns>

    init() {
        var list = SavedPatterns.examples()
        let examples = list.patterns.map(\.id)
        let doc = (try? list.save(name: "Doc", text: "Doc {text}").get()) ?? ""
        _ = list.save(name: "Company", text: "Co {company}")
        list.makeDefault(doc)
        for id in examples { list.remove(id) }
        state = Mutex(list)
    }

    var list: SavedPatterns { state.withLock { $0 } }

    func save(name: String, text: String) -> SavedPatterns.Problem? {
        state.withLock { list in
            if case .failure(let problem) = list.save(name: name, text: text) { return problem }
            return nil
        }
    }
}
