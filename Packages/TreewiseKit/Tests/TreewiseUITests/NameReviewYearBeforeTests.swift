import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// The names in the same folder a year before, for an add-on that reads them (ADR 0090).
@MainActor
@Suite struct NameReviewYearBeforeTests {
    private static let reader = NameModuleDescription(
        id: "advanced", contentTypes: ["public.item"], neededContent: [],
        fields: [.init(name: "text", kind: .text)], defaultTemplate: "Adv {text}",
        name: "Advanced", readsYearBefore: true)
    private static let other = NameModuleDescription(
        id: "other", contentTypes: ["public.item"], neededContent: [],
        fields: [.init(name: "text", kind: .text)], defaultTemplate: "Other {text}",
        name: "Other")

    private let fileSystem = ChangingFileSystem()
    private let volume: VolumeID

    init() async throws {
        volume = try await fileSystem.item(at: "documents").volume
        for path in ["Admin", "Admin/2025", "Admin/2026", "Admin/2025/Tax", "Admin/2026/Tax"] {
            addFolder(path)
        }
    }

    private func addFolder(_ path: String) {
        let parent = path.split(separator: "/").dropLast().joined(separator: "/")
        fileSystem.add(
            FileItem(
                id: FileItem.ID(path), name: String(path.split(separator: "/").last ?? ""),
                kind: .folder, parentID: FileItem.ID(parent.isEmpty ? "documents" : parent),
                volume: volume))
    }

    private func addFile(_ name: String, in folder: String, hidden: Bool = false) {
        fileSystem.add(
            FileItem(
                id: FileItem.ID("\(folder)/\(name)"), name: name, kind: .file,
                parentID: FileItem.ID(folder), volume: volume, isHidden: hidden))
    }

    private func model(
        of path: String, _ host: ScriptedModuleHost, addOns: AddOnPreferences = AddOnPreferences()
    ) async throws -> NameReviewModel {
        let folder = try await fileSystem.item(at: FileItem.ID(path))
        let model = NameReviewModel(
            folder: folder, scope: .wholeFolder, selection: [],
            dependencies: .init(
                operations: fileSystem, host: host, store: MemoryFolderSettings(),
                defaultPattern: "Std {text}", addOns: addOns,
                makeRequest: { item, _, _ in
                    NameRequest(
                        id: item.id.rawValue, name: item.name, contentType: "public.plain-text",
                        byteCount: nil, created: nil, modified: nil, suggestedDate: nil,
                        siblingNames: [], content: ModuleContent())
                }))
        await model.start()
        await model.waitUntilRead()
        return model
    }

    private func host(_ modules: [NameModuleDescription] = [reader]) -> ScriptedModuleHost {
        ScriptedModuleHost(
            modules: modules,
            answers: Dictionary(
                uniqueKeysWithValues: modules.map { ($0.id, .success([["text": .text("A")]])) }))
    }

    private func yearsAsked(by moduleID: String, in host: ScriptedModuleHost) -> [FolderYears?] {
        host.yearsAskedAbout.filter { $0.moduleID == moduleID }.map(\.years)
    }

    @Test func givesAnAddOnThatAsksTheNamesOfTheSameFolderAYearBefore() async throws {
        addFile("Tax 2025.1.pdf", in: "Admin/2025/Tax")
        addFile("Tax 2025.2.pdf", in: "Admin/2025/Tax")
        addFile("Tax 2026.1.pdf", in: "Admin/2026/Tax")
        let host = host()
        _ = try await model(of: "Admin/2026/Tax", host)
        let years = yearsAsked(by: "advanced", in: host)
        #expect(years.first??.year == 2026)
        #expect(years.first??.namesYearBefore.sorted() == ["Tax 2025.1.pdf", "Tax 2025.2.pdf"])
    }

    @Test func givesThemToNoAddOnThatDoesNotAsk() async throws {
        addFile("Tax 2025.1.pdf", in: "Admin/2025/Tax")
        let host = host([Self.reader, Self.other])
        var addOns = AddOnPreferences()
        addOns.setOnInNewFolders("other", on: true, catalog: ["advanced", "other"], defaultID: "")
        _ = try await model(of: "Admin/2026/Tax", host, addOns: addOns)
        #expect(yearsAsked(by: "other", in: host) == [nil])
    }

    @Test func givesThemToNoAddOnWhenTheUserTurnedItOff() async throws {
        addFile("Tax 2025.1.pdf", in: "Admin/2025/Tax")
        var addOns = AddOnPreferences()
        addOns.readsYearBefore = false
        let host = host()
        let model = try await model(of: "Admin/2026/Tax", host, addOns: addOns)
        #expect(yearsAsked(by: "advanced", in: host) == [nil])
        #expect(!model.readsYearBefore)
    }

    @Test func givesNoneWhenTheFolderAYearBeforeIsNotThere() async throws {
        addFolder("Admin/2026/Bank")
        let host = host()
        let model = try await model(of: "Admin/2026/Bank", host)
        #expect(yearsAsked(by: "advanced", in: host) == [nil])
        #expect(!model.readsYearBefore)
    }

    @Test func leavesOutHiddenFilesAndFoldersOfTheYearBefore() async throws {
        addFile("Tax 2025.1.pdf", in: "Admin/2025/Tax")
        addFile(".DS_Store", in: "Admin/2025/Tax", hidden: true)
        addFolder("Admin/2025/Tax/Old")
        let host = host()
        let model = try await model(of: "Admin/2026/Tax", host)
        #expect(yearsAsked(by: "advanced", in: host).first??.namesYearBefore == ["Tax 2025.1.pdf"])
        #expect(model.readsYearBefore)
    }

    /// A new year's folder: the pattern counts against the names of the year before.
    @Test func aNewYearsFolderCountsThePatternAgainstTheYearBefore() async throws {
        for number in 1...4 { addFile("Tax 2025.\(number).pdf", in: "Admin/2025/Tax") }
        addFile("Note.pdf", in: "Admin/2025/Tax")
        addFile("Tax 2026.1.pdf", in: "Admin/2026/Tax")
        let host = host()
        host.setDerivedTemplate("Tax {year}.{seq:4:1}", for: "advanced")
        let model = try await model(of: "Admin/2026/Tax", host)
        let module = try #require(model.modules.first)
        #expect(module.recognizedInYearBefore)
        #expect(module.candidates.first?.fits == 4)
        #expect(module.candidates.first?.of == 5)
        #expect(!module.hasTooFewNamesForAPattern)
    }

    @Test func aFolderWithNamesEnoughCountsItsOwn() async throws {
        for number in 1...4 { addFile("Tax 2025.\(number).pdf", in: "Admin/2025/Tax") }
        for number in 1...3 { addFile("Tax 2026.\(number).pdf", in: "Admin/2026/Tax") }
        let host = host()
        host.setDerivedTemplate("Tax {year}.{seq:4:1}", for: "advanced")
        let model = try await model(of: "Admin/2026/Tax", host)
        let module = try #require(model.modules.first)
        #expect(!module.recognizedInYearBefore)
        #expect(module.candidates.first?.of == 3)
    }

    @Test func readingTheYearBeforeIsOnUntilTheUserTurnsItOff() {
        #expect(AddOnPreferences().readsYearBefore)
    }

    @Test func keepsTheSettingTurnedOff() throws {
        var addOns = AddOnPreferences()
        addOns.readsYearBefore = false
        let kept = try JSONDecoder().decode(
            AddOnPreferences.self, from: JSONEncoder().encode(addOns))
        #expect(kept == addOns)
        #expect(!kept.readsYearBefore)
    }

    @Test func preferencesKeptBeforeTheSettingReadItAsOn() throws {
        let kept = try JSONEncoder().encode(AddOnPreferences())
        var json = try #require(
            try JSONSerialization.jsonObject(with: kept) as? [String: Any])
        json.removeValue(forKey: "yearBeforeTurnedOff")
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode(AddOnPreferences.self, from: old).readsYearBefore)
    }
}
