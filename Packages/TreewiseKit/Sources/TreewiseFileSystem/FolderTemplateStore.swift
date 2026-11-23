import Foundation
import TreewiseCore
import os

/// Keeps folder structure templates in Treewise's own folder, one JSON file each, named by
/// the template's id (ADR 0091, ADR 0097). A deleted template's file goes to the Trash, as
/// any deleted file does in Treewise (ADR 0004), so it can still be imported from there.
/// Where Treewise's own folder has no Trash, as on the iPad, it goes to a folder of the
/// store's own beside it, out of the user's sight, until `emptyDeleted()` at the next start;
/// Undo brings it back from either.
public actor FolderTemplateStore: FolderTemplateStoring {
    private static let logger = Logger(
        subsystem: LogSubsystem.name, category: "FolderTemplateStore")

    private let directory: URL
    /// Where a deleted template's file is kept where there is no Trash.
    private let deletedDirectory: URL
    /// Puts a file in the Trash and says where.
    private let trash: @Sendable (FileItem.ID) throws -> TrashedItem
    /// Where what the user changes is told, in order, for a sync to record (ADR 0144).
    var notices: NoticeLine<FolderTemplateNotice>?

    /// Creates a store that keeps its files in `directory`, made when the first is saved, and
    /// puts a deleted one in the Trash with `trash`, or beside `directory` where that has no
    /// Trash.
    public init(
        directory: URL,
        trash: @escaping @Sendable (FileItem.ID) throws -> TrashedItem = {
            try TrashService().trash($0)
        }
    ) {
        self.directory = directory
        deletedDirectory = directory.deletingLastPathComponent()
            .appendingPathComponent("Deleted Templates", isDirectory: true)
        self.trash = trash
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
        let before = notices == nil ? nil : Self.read(file(of: template.id))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FolderTemplateFile.data(of: template).write(to: file(of: template.id), options: .atomic)
        notices?.tell(.saved(template, before: before))
    }

    /// Puts the file of the template with this id in the Trash, or in the store's own folder
    /// where there is no Trash, and says where, so Undo can bring it back.
    @discardableResult
    public func delete(id: String) throws -> TrashedItem {
        let before = notices == nil ? nil : Self.read(file(of: id))
        let original = FileItem.ID(file(of: id).path)
        let trashed: TrashedItem
        do {
            trashed = try trash(original)
        } catch FileSystemError.trashUnavailable {
            trashed = try keepDeleted(original, id: id)
        }
        notices?.tell(.deleted(id: id, before: before))
        return trashed
    }

    /// Moves a deleted template's file into the store's own folder for deleted ones, under a
    /// name of its own, as the Trash would.
    private func keepDeleted(_ original: FileItem.ID, id: String) throws -> TrashedItem {
        let kept = deletedDirectory.appendingPathComponent(
            "\(id) \(UUID().uuidString).\(FolderTemplateFile.pathExtension)")
        try FileManager.default.createDirectory(
            at: deletedDirectory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: file(of: id), to: kept)
        return TrashedItem(trashID: FileItem.ID(kept.path), originalID: original)
    }

    /// Removes the templates deleted where there was no Trash: Treewise's own copies, kept
    /// only for Undo, which does not outlast the app; no file of the user's (ADR 0004).
    public func emptyDeleted() {
        guard FileManager.default.fileExists(atPath: deletedDirectory.path) else { return }
        do {
            try FileManager.default.removeItem(at: deletedDirectory)
        } catch {
            Self.logger.error("Deleted templates not emptied: \(error.localizedDescription)")
        }
    }

    /// Brings back a template's file that `delete(id:)` put in the Trash.
    public func restore(_ trashed: TrashedItem) throws {
        try TrashService().restore(trashed)
        let id = URL(filePath: trashed.originalID.rawValue).deletingPathExtension()
            .lastPathComponent
        if let template = Self.read(file(of: id)) {
            notices?.tell(.saved(template, before: nil))
        }
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

    func file(of id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension(
            FolderTemplateFile.pathExtension)
    }
}
