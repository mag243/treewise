import Foundation
import Observation
import TreewiseCore

/// Rename in All Years… (ADR 0139): a folder inside a year's own folder, found at the same
/// place in every year's folder beside it, and the one new name they get, as the sheet
/// shows and edits it.
@MainActor
@Observable
public final class RenameInAllYearsModel {
    /// The name of the folder the user chose.
    public let oldName: String
    /// Its path below its year's folder, as `["Q1", "Tax"]`.
    public let path: [String]
    /// Every year's own folder beside the chosen one's, its own included, by year.
    public let years: [FileItem.ID]
    /// In each year that has the folders above the chosen one, the folder that would hold
    /// it and what that folder holds, by year.
    private let holders: [(parent: FileItem.ID, contents: [FileItem])]
    /// The templates to correct along that hold a folder at that path: those the years were
    /// made from (ADR 0141), the one used last first, or, when no year keeps one, those
    /// rooted at `{year}` (ADR 0102).
    public let templates: [FolderTemplate]
    /// The new name, as typed.
    public var newName: String
    /// The folders the user unchecked.
    public var excluded: Set<FileItem.ID> = []
    /// The ids of the templates the user unchecked, which are not corrected along.
    public var uncorrected: Set<String> = []

    init(
        oldName: String, path: [String], years: [FileItem.ID],
        holders: [(parent: FileItem.ID, contents: [FileItem])], templates: [FolderTemplate]
    ) {
        self.oldName = oldName
        self.path = path
        self.years = years
        self.holders = holders
        self.templates = templates
        newName = oldName
    }

    /// The model for `folder`, or nil when it is in no year's own folder; `madeFrom` gives
    /// the ids of the templates a year's folder was made from.
    public static func make(
        for folder: FileItem, in fileSystem: any FileSystemProviding,
        templates: [FolderTemplate],
        madeFrom: (FileItem.ID) async -> [String] = { _ in [] }
    ) async -> RenameInAllYearsModel? {
        guard let (year, path) = YearFolders.place(of: folder.id),
            let parent = try? await fileSystem.item(at: year).parentID,
            let beside = try? await fileSystem.contents(of: parent)
        else { return nil }
        let years = beside.filter { $0.kind == .folder && YearFolders.year(named: $0.name) != nil }
            .sorted { $0.name < $1.name }.map(\.id)
        var holders: [(parent: FileItem.ID, contents: [FileItem])] = []
        for year in years {
            if let holder = await Self.holder(of: path, in: year, fileSystem: fileSystem) {
                holders.append(holder)
            }
        }
        var kept: [String] = []
        for year in years {
            for id in await madeFrom(year).reversed() where !kept.contains(id) { kept.append(id) }
        }
        let holding = templates.filter {
            $0.root.renamingFolder(atDiskPath: path, to: folder.name) != nil
        }
        let chosen =
            kept.isEmpty
            ? holding.filter(\.isRootedAtYear)
            : kept.compactMap { id in holding.first { $0.id == id } }
        return RenameInAllYearsModel(
            oldName: folder.name, path: path, years: years, holders: holders, templates: chosen)
    }

    /// The folder below `year` that would hold the last folder of `path`, with what it
    /// holds, or nil when a folder above is missing. Names compare as the file system
    /// compares them.
    private static func holder(
        of path: [String], in year: FileItem.ID, fileSystem: any FileSystemProviding
    ) async -> (parent: FileItem.ID, contents: [FileItem])? {
        var parent = year
        for name in path.dropLast() {
            guard let contents = try? await fileSystem.contents(of: parent),
                let folder = folder(named: name, in: contents)
            else { return nil }
            parent = folder.id
        }
        guard let contents = try? await fileSystem.contents(of: parent) else { return nil }
        return (parent, contents)
    }

    private static func folder(named name: String, in contents: [FileItem]) -> FileItem? {
        let key = ConflictResolver.comparisonKey(name)
        return contents.first {
            $0.kind == .folder && ConflictResolver.comparisonKey($0.name) == key
        }
    }

    /// The folders that get the new name, by year: the one at the chosen folder's path, or
    /// where it has none, one with the new name already.
    public var places: [OneFolderName.Place] {
        holders.compactMap { holder in
            guard
                let folder = Self.folder(named: oldName, in: holder.contents)
                    ?? Self.folder(named: trimmedName, in: holder.contents)
            else { return nil }
            return OneFolderName.Place(
                folder: folder.id, parent: holder.parent, name: folder.name,
                namesBeside: holder.contents.map(\.name))
        }
    }

    /// The new name without spaces around it.
    public var trimmedName: String { newName.trimmingCharacters(in: .whitespaces) }

    /// What happens to each folder with the new name.
    public var plan: OneFolderName { OneFolderName(places, to: trimmedName) }

    /// The renames of the folders checked.
    public var renames: [BatchRename] {
        plan.renames.filter { !excluded.contains($0.item) }
    }

    /// Whether Rename can be chosen: a valid new name and a folder to give it.
    public var canRename: Bool { FileName.isValid(trimmedName) && !renames.isEmpty }

    /// The templates checked, with the folder renamed.
    public var correctedTemplates: [FolderTemplate] {
        templates.filter { !uncorrected.contains($0.id) }.compactMap { template in
            var corrected = template
            guard let root = template.root.renamingFolder(atDiskPath: path, to: trimmedName)
            else { return nil }
            corrected.root = root
            return corrected
        }
    }

    /// How a folder's year is shown: its year, with the folders between, as `2025 › Q1`.
    public func label(of place: OneFolderName.Place) -> String {
        guard let (year, path) = YearFolders.place(of: place.folder) else { return place.name }
        let yearName = year.rawValue.split(separator: "/").last.map(String.init) ?? ""
        return ([yearName] + path.dropLast()).joined(separator: " › ")
    }
}
