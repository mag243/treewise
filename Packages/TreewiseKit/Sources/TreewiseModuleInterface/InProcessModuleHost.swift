import Foundation
import TreewiseCore

/// How much one host gives back, alike wherever the modules run.
public enum AddOnLimits {
    /// The most templates a module's recognition offers (ADR 0067).
    public static let maximumTemplates = 5
}

/// Runs add-ons inside the app's own process, as the iPad does with the free modules, which
/// are Treewise's own open-source code (ADR 0129). They get the same data as in the Mac's
/// service, nothing to reach a file by, and their answers keep the same limits; the Mac runs
/// its modules in a service of their own instead (ADR 0057).
public struct InProcessModuleHost: AddOnHosting {
    private let modules: [any AddOnModule]

    /// Creates a host that runs `modules` and no other.
    public init(modules: [any AddOnModule]) {
        self.modules = modules
    }

    public func availableModules() async throws -> [AddOnDescription] {
        modules.map(\.description)
    }

    public func fieldValues(moduleID: String, request: NameRequest) async throws
        -> [[String: NameTemplate.Value]]
    {
        try await nameModule(moduleID).fieldValues(for: request)
    }

    public func derivedTemplates(
        moduleID: String, names: [String], folderName: String, years: FolderYears?,
        licence: LicenceContext
    ) async throws -> [String] {
        let templates = try nameModule(moduleID).derivedTemplates(
            fromNames: names, folderName: folderName, years: years, licence: licence)
        return Array(templates.prefix(AddOnLimits.maximumTemplates))
    }

    public func licenceState(moduleID: String, licence: LicenceContext) async throws
        -> ModuleLicenceState?
    {
        guard let module = modules.first(where: { $0.id == moduleID }) else {
            throw NameModuleHostError.moduleFailed
        }
        return module.licenceState(licence: licence)
    }

    public func template(
        moduleID: String, from tree: FolderTree, yearAbove: Int?, licence: LicenceContext
    ) async throws -> FolderTree? {
        guard
            let module = modules.first(where: { $0.id == moduleID })
                as? any FolderStructureModule
        else { throw NameModuleHostError.moduleFailed }
        return module.template(from: tree, yearAbove: yearAbove, licence: licence)
    }

    private func nameModule(_ id: String) throws -> any NameModule {
        guard let module = modules.first(where: { $0.id == id }) as? any NameModule else {
            throw NameModuleHostError.moduleFailed
        }
        return module
    }
}
