import Foundation

/// Where folder structure templates are kept (ADR 0091, ADR 0097).
public protocol FolderTemplateStoring: Sendable {
    /// The templates, ordered by name.
    func templates() async -> [FolderTemplate]
    /// Saves a template under its id, replacing what was saved under it.
    func save(_ template: FolderTemplate) async throws
    /// Puts the template with this id away, so `restore` can bring it back.
    func delete(id: String) async throws -> TrashedItem
    /// Brings back a template `delete(id:)` put away.
    func restore(_ trashed: TrashedItem) async throws
    /// Saves the template in a file as a new one, with a new id and a name of its own.
    func importTemplate(from data: Data) async throws(FolderTemplateFile.Problem)
        -> FolderTemplate
}
