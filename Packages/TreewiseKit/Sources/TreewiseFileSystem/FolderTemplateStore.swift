import Foundation
import TreewiseCore
import os

/// Keeps folder structure templates in Treewise's own folder, one JSON file each, named by
/// the template's id (ADR 0091, ADR 0097). A deleted template's file goes to the Trash, as
/// any deleted file does in Treewise (ADR 0004), so it can still be imported from there.
public actor FolderTemplateStore: FolderTemplateStoring {
    private static let logger = Logger(
        subsystem: LogSubsystem.name, category: "FolderTemplateStore")

    private let directory: URL

    /// Creates a store that keeps its files in `directory`, made when the first is saved.
    public init(directory: URL) {
        self.directory = directory
    }

    /// The folder Treewise keeps templates in by default.
    public static var defaultDirectory: URL {
        FolderSettingsStore.defaultDirectory.appendingPathComponent(
            "Templates", isDirectory: true)
    }

    /// The templates, ordered by name as Finder orders names. A file that is no template is
    /// left out and logged.
    public func templates() -> [FolderTemplate] {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == FolderTemplateFile.pathExtension }
            .compactMap(Self.read)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func read(_ file: URL) -> FolderTemplate? {
        let id = file.deletingPathExtension().lastPathComponent
        do {
            return try FolderTemplateFile.template(from: Data(contentsOf: file), id: id)
        } catch {
            logger.error("Template unreadable: \(file.lastPathComponent, privacy: .public)")
            return nil
        }
    }

    /// Saves a template under its id, replacing what was saved under it.
    public func save(_ template: FolderTemplate) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FolderTemplateFile.data(of: template).write(to: file(of: template.id), options: .atomic)
    }

    /// Puts the file of the template with this id in the Trash, and says where, so Undo can
    /// bring it back.
    @discardableResult
    public func delete(id: String) throws -> TrashedItem {
        try TrashService().trash(FileItem.ID(file(of: id).path))
    }

    /// Brings back a template's file that `delete(id:)` put in the Trash.
    public func restore(_ trashed: TrashedItem) throws {
        try TrashService().restore(trashed)
    }

    /// Saves the template in a file as a new one and, when its name is taken, `name 2`,
    /// `name 3`, …; under the id the file holds when `keepingID` and no template has it, else
    /// under a new id (ADR 0141).
    /// - Throws: the file's problem, or `.notSaved` when the template cannot be kept.
    public func importTemplate(from data: Data, keepingID: Bool) throws(FolderTemplateFile.Problem)
        -> FolderTemplate
    {
        let here = templates()
        let fileID = keepingID ? FolderTemplateFile.id(in: data) : nil
        let id = fileID.flatMap { id in here.contains { $0.id == id } ? nil : id }
        let read = try FolderTemplateFile.template(from: data, id: id ?? UUID().uuidString)
        let name = FolderTemplate.uniqueName(read.name, among: Set(here.map(\.name)))
        let template = FolderTemplate(id: read.id, name: name, root: read.root)
        do {
            try save(template)
        } catch {
            Self.logger.error("Imported template not saved: \(error.localizedDescription)")
            throw .notSaved
        }
        return template
    }

    private func file(of id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension(
            FolderTemplateFile.pathExtension)
    }
}
