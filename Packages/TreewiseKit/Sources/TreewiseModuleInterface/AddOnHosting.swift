import Foundation
import TreewiseCore

/// Why a module gave no answer. None of this stops the app: it goes on with the
/// proposals it has (ADR 0057).
public enum NameModuleHostError: Error, Hashable, Sendable {
    /// The modules' process could not be reached, or stopped.
    case unavailable
    /// No answer came in time.
    case timedOut
    /// The module failed, or is not known.
    case moduleFailed
    /// The answer was too large or could not be read.
    case invalidResponse
}

/// Where the app reaches its modules, wherever they run (ADR 0057).
public protocol AddOnHosting: Sendable {
    /// The modules on offer.
    func availableModules() async throws -> [AddOnDescription]
    /// Asks a module for ranked sets of values. A request must hold only what the
    /// module declared.
    func fieldValues(moduleID: String, request: NameRequest) async throws
        -> [[String: NameTemplate.Value]]
    /// Asks a module which templates a folder's names might follow, the best first; none
    /// when it recognizes none (ADR 0067). `years` holds the folder's year and the names a
    /// year before, for a module that reads them (ADR 0090).
    func derivedTemplates(
        moduleID: String, names: [String], folderName: String, years: FolderYears?,
        licence: LicenceContext
    ) async throws -> [String]
    /// Asks a module what its licence lets it do; nil when it needs no licence (ADR 0071).
    func licenceState(moduleID: String, licence: LicenceContext) async throws
        -> ModuleLicenceState?
    /// Asks an add-on that makes folder structures for the template of a folder's tree, or
    /// nil while it may not work (ADR 0091).
    func template(moduleID: String, from tree: FolderTree, licence: LicenceContext)
        async throws -> FolderTree?
    /// Asks an add-on that makes folder structures for the folders a template makes with its
    /// fields filled in from `values`, or nil while it may not work. What comes back has
    /// passed `FolderTree.check()` and holds no field.
    func foldersToMake(
        moduleID: String, template: FolderTree, values: FolderTemplateValues,
        licence: LicenceContext
    ) async throws -> FolderTree?
}

extension AddOnHosting {
    /// A host without add-ons that make folder structures has none to ask.
    public func template(moduleID: String, from tree: FolderTree, licence: LicenceContext)
        async throws -> FolderTree?
    {
        throw NameModuleHostError.moduleFailed
    }

    /// A host without add-ons that make folder structures has none to ask.
    public func foldersToMake(
        moduleID: String, template: FolderTree, values: FolderTemplateValues,
        licence: LicenceContext
    ) async throws -> FolderTree? {
        throw NameModuleHostError.moduleFailed
    }

    /// Asks a module which templates a folder's names might follow, without the year before.
    public func derivedTemplates(
        moduleID: String, names: [String], folderName: String, licence: LicenceContext
    ) async throws -> [String] {
        try await derivedTemplates(
            moduleID: moduleID, names: names, folderName: folderName, years: nil,
            licence: licence)
    }
}
