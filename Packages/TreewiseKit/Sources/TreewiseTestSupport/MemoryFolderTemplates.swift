import Foundation
import TreewiseCore

/// Templates kept in memory, for tests of what uses them.
public actor MemoryFolderTemplates: FolderTemplateStoring {
    private var kept: [String: FolderTemplate]
    private var putAway: [FileItem.ID: FolderTemplate] = [:]

    /// A store holding `templates`.
    public init(_ templates: [FolderTemplate] = []) {
        kept = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
    }

    public func templates() -> [FolderTemplate] {
        kept.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func save(_ template: FolderTemplate) {
        kept[template.id] = template
    }

    public func delete(id: String) throws -> TrashedItem {
        guard let template = kept.removeValue(forKey: id) else {
            throw FileSystemError.notFound(FileItem.ID(id))
        }
        let trashed = TrashedItem(trashID: FileItem.ID("trash/\(id)"), originalID: FileItem.ID(id))
        putAway[trashed.trashID] = template
        return trashed
    }

    public func restore(_ trashed: TrashedItem) throws {
        guard let template = putAway.removeValue(forKey: trashed.trashID) else {
            throw FileSystemError.notFound(trashed.trashID)
        }
        kept[template.id] = template
    }

    public func importTemplate(from data: Data, keepingID: Bool) throws(FolderTemplateFile.Problem)
        -> FolderTemplate
    {
        let fileID = keepingID ? FolderTemplateFile.id(in: data) : nil
        let id = fileID.flatMap { kept[$0] == nil ? $0 : nil }
        let read = try FolderTemplateFile.template(from: data, id: id ?? UUID().uuidString)
        let name = FolderTemplate.uniqueName(read.name, among: Set(kept.values.map(\.name)))
        let template = FolderTemplate(id: read.id, name: name, root: read.root)
        kept[template.id] = template
        return template
    }
}
