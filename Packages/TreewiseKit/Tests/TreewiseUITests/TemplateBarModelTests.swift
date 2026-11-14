import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// The bar in an empty folder, read from the folders and their settings (ADR 0094, 0097).
@MainActor
@Suite struct TemplateBarModelTests {
    private static let year = FolderTemplate(
        id: "year", name: "Household Year", root: FolderTree(name: "{year}"))
    private static let client = FolderTemplate(
        id: "client", name: "Client", root: FolderTree(name: "{text}"))

    let fileSystem = ChangingFileSystem()
    let settings = MemoryFolderSettings()
    let templates = MemoryFolderTemplates([year, client])

    private func model(mayWork: Bool = true) -> TemplateBarModel {
        TemplateBarModel(
            fileSystem: fileSystem, settings: settings, templates: templates,
            addOnMayWork: { mayWork })
    }

    /// A folder whose id is its path, as on disk, so the year in it counts.
    private func folder(_ name: String, in parent: FileItem.ID) async throws -> FileItem {
        let above = try await fileSystem.item(at: parent)
        let folder = FileItem(
            id: FileItem.ID("\(parent.rawValue)/\(name)"), name: name, kind: .folder,
            parentID: parent, volume: above.volume)
        fileSystem.add(folder)
        return folder
    }

    @Test func offersTheOneYearTemplateInAnEmptyYearsFolder() async throws {
        let household = try await folder("Household", in: "documents")
        let year = try await folder("2027", in: household.id)
        let offer = await model().offer(in: year)
        #expect(offer?.source == .template(Self.year))
    }

    @Test func offersNothingWhileTheAddOnMayNotWork() async throws {
        let household = try await folder("Household", in: "documents")
        let year = try await folder("2027", in: household.id)
        #expect(await model(mayWork: false).offer(in: year) == nil)
    }

    @Test func offersNothingOnceTheFolderHoldsSomething() async throws {
        let household = try await folder("Household", in: "documents")
        let year = try await folder("2027", in: household.id)
        _ = try await folder("Tax", in: year.id)
        #expect(await model().offer(in: year) == nil)
    }

    @Test func closingTheBarKeepsItClosedForThatFolder() async throws {
        let household = try await folder("Household", in: "documents")
        let year = try await folder("2027", in: household.id)
        let model = model()
        await model.close(in: year.id)
        #expect(await model.offer(in: year) == nil)
    }

    @Test func theCheckboxOffersItsTemplateInEachNewFolderAndNoneStopsIt() async throws {
        let clients = try await folder("Clients", in: "documents")
        let acme = try await folder("Acme", in: clients.id)
        let model = model()
        #expect(await model.offer(in: acme) == nil)
        await model.offer("client", in: clients.id)
        #expect(await model.offer(in: acme)?.source == .template(Self.client))
        await model.offerNothing(in: clients.id)
        #expect(await model.offer(in: acme) == nil)
    }
}
