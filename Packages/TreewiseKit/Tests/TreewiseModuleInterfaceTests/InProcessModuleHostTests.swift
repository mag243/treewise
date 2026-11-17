import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface

/// The host that runs the free modules inside the app, as the iPad does (ADR 0129).
@Suite struct InProcessModuleHostTests {
    /// A name module that answers with what it was given, to see the host pass it on.
    private struct EchoModule: NameModule {
        let description = AddOnDescription(
            id: "echo", contentTypes: ["public.data"], neededContent: [], fields: [],
            defaultTemplate: "{text}", isFree: true)

        func fieldValues(for request: NameRequest) async throws -> [[String: NameTemplate.Value]] {
            [["text": .text(request.name)]]
        }

        func derivedTemplates(
            fromNames names: [String], folderName: String, years: FolderYears?,
            licence: LicenceContext
        ) -> [String] {
            (1...9).map { "{text} \(folderName) \($0)" }
        }
    }

    /// An add-on of the other kind, which makes folder structures.
    private struct StructureModule: FolderStructureModule {
        let description = AddOnDescription(id: "structure", kind: .folderStructure)

        func template(from tree: FolderTree, yearAbove: Int?, licence: LicenceContext)
            -> FolderTree?
        {
            tree
        }
    }

    private let host = InProcessModuleHost(modules: [EchoModule(), StructureModule()])

    private func request(_ name: String) -> NameRequest {
        NameRequest(
            id: "1", name: name, contentType: "public.data", byteCount: 1, created: nil,
            modified: nil, siblingNames: [], content: ModuleContent())
    }

    @Test func listsTheModulesItRuns() async throws {
        #expect(try await host.availableModules().map(\.id) == ["echo", "structure"])
    }

    @Test func passesARequestToItsModule() async throws {
        let values = try await host.fieldValues(moduleID: "echo", request: request("Beach.jpg"))

        #expect(values == [["text": .text("Beach.jpg")]])
    }

    @Test func givesAtMostAsManyTemplatesAsTheMacsService() async throws {
        let templates = try await host.derivedTemplates(
            moduleID: "echo", names: ["a", "b", "c"], folderName: "Trip", licence: .none)

        #expect(templates.count == AddOnLimits.maximumTemplates)
        #expect(templates.first == "{text} Trip 1")
    }

    @Test func refusesAModuleItDoesNotRun() async {
        await #expect(throws: NameModuleHostError.moduleFailed) {
            try await host.fieldValues(moduleID: "advanced", request: request("Beach.jpg"))
        }
    }

    @Test func asksAnAddOnThatMakesFolderStructures() async throws {
        let tree = FolderTree(name: "2026", folders: [FolderTree(name: "Tax")])

        let template = try await host.template(
            moduleID: "structure", from: tree, yearAbove: nil, licence: .none)

        #expect(template == tree)
    }
}
