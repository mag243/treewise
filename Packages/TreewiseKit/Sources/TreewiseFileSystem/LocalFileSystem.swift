import Foundation
import TreewiseCore

/// The local disk behind `FileSystemProviding`: items are identified by their
/// standardized path, read with `URLResourceValues` (ADR 0016).
public struct LocalFileSystem: FileSystemProviding {
    /// The resource values every item is read with.
    static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey,
        .localizedTypeDescriptionKey, .contentModificationDateKey, .fileSizeKey, .volumeURLKey,
        .volumeLocalizedNameKey, .isHiddenKey, .localizedNameKey,
    ]

    /// The resource values read for each item of a folder: the per-file facts,
    /// without the kind text and the volume, which are slow to read per file
    /// and the same for most items of a folder (ADR 0016).
    static let listingKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isPackageKey, .isVolumeKey,
        .contentModificationDateKey, .fileSizeKey, .isHiddenKey,
    ]

    /// The names Treewise gives its own temporary items: partial copies
    /// (ADR 0018) and inboxes of promised files (ADR 0020). They are never listed.
    static let temporaryPrefixes = [FileCopier.partialPrefix, PromiseInbox.prefix]

    /// Where the sidebar's folders and volumes are.
    public let locations: Locations
    /// The cloud folders at a fixed place, read once: listing a folder asks for
    /// each of its subfolders whether it is one.
    private let fixedCloudFolders: Set<FileItem.ID>
    /// The folder whose subfolders are cloud folders.
    private let cloudStorage: FileItem.ID
    /// The user's home folder.
    private let homeFolder: FileItem.ID
    /// The folder holding iCloud Drive's files, which goes by a name of its own.
    private let iCloudDrive: FileItem.ID

    /// Creates a provider for the local disk. Folders list their hidden items
    /// too, marked `isHidden`; whether they show is the window's setting (ADR 0023).
    public init(locations: Locations = .system) {
        self.locations = locations
        homeFolder = Self.identity(of: locations.home)
        iCloudDrive = Self.identity(of: locations.iCloudDrive)
        fixedCloudFolders = Set(
            ([locations.iCloudDrive] + locations.syncFolders).map(Self.identity))
        cloudStorage = Self.identity(of: locations.cloudStorage)
    }

    /// The identities of the folders containing a path, nearest first, derived
    /// from the path alone without reading the disk.
    public static func ancestry(_ id: FileItem.ID) -> [FileItem.ID] {
        var components = id.rawValue.split(separator: "/").map(String.init)
        var ancestors: [FileItem.ID] = []
        while !components.isEmpty {
            components.removeLast()
            ancestors.append(FileItem.ID("/" + components.joined(separator: "/")))
        }
        return ancestors
    }

    /// Whether an item is inside the boundary: at or below one of its folders.
    public func isInsideBoundary(_ id: FileItem.ID) -> Bool {
        guard id != .computer, let boundary = locations.boundary else { return true }
        return boundary.contains { root in
            let rootPath = root.standardizedFileURL.path
            return id.rawValue == rootPath || id.rawValue.hasPrefix(rootPath + "/")
        }
    }

    /// - Throws: `FileSystemError.outsideBoundary` when `id` is outside the boundary.
    public func checkBoundary(_ id: FileItem.ID) throws {
        guard isInsideBoundary(id) else { throw FileSystemError.outsideBoundary(id) }
    }

    public func contents(of folder: FileItem.ID) async throws -> [FileItem] {
        if folder == .computer { return try await locations() }
        try checkBoundary(folder)
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: url(of: folder), includingPropertiesForKeys: Array(Self.listingKeys))
        } catch {
            throw Self.fileSystemError(error, for: folder)
        }
        let volume = try? url(of: folder).resourceValues(forKeys: [.volumeURLKey]).volume
        var kindTexts = KindTextCache()
        let asksCloudStatus = isInCloudFolder(folder)
        // An entry that disappears between listing and reading is left out.
        return urls.compactMap { child -> FileItem? in
            let fileName = child.lastPathComponent
            guard !Self.temporaryPrefixes.contains(where: fileName.hasPrefix) else { return nil }
            let id = childID(of: folder, named: fileName)
            guard let values = try? child.resourceValues(forKeys: Self.listingKeys) else {
                return nil
            }
            // A mount point is on a volume of its own: read it in full.
            if values.isVolume == true { return try? makeItem(id: id) }
            let kind = kind(of: id, values: values, isVolumeRoot: false)
            var item = FileItem(
                id: id, name: name(of: id, kind: kind, values: values), kind: kind,
                parentID: folder, volume: VolumeID(volume?.path ?? "/"),
                modified: values.contentModificationDate,
                size: values.isRegularFile == true ? values.fileSize.map(Int64.init) : nil,
                kindDescription: kindTexts.text(for: child, values: values),
                isHidden: values.isHidden ?? fileName.hasPrefix("."))
            item.isOnlyOnline =
                asksCloudStatus && !kind.isContainer && locations.isOnlyOnline(child)
            return item
        }
    }

    public func item(at id: FileItem.ID) async throws -> FileItem {
        try currentItem(at: id)
    }

    /// Reads an item without suspending, for callers that must answer at once,
    /// such as AppKit asking what a drop would do while the pointer moves.
    public func currentItem(at id: FileItem.ID) throws -> FileItem {
        if id == .computer { return .computer() }
        try checkBoundary(id)
        do {
            return try makeItem(id: id)
        } catch {
            throw Self.fileSystemError(error, for: id)
        }
    }

    public func availableCapacity(of folder: FileItem.ID) async throws -> Int64? {
        if folder == .computer { return nil }
        try checkBoundary(folder)
        let values: URLResourceValues
        do {
            values = try url(of: folder).resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
            ])
        } catch {
            throw Self.fileSystemError(error, for: folder)
        }
        return values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
    }

    func url(of id: FileItem.ID) -> URL {
        URL(fileURLWithPath: id.rawValue)
    }

    /// Reads an item. `kind` overrides the kind read from disk, for locations.
    /// It reads through a URL made for this read: a URL caches the values it
    /// read, and off the main run loop that cache is never flushed, so a URL
    /// kept around would go on showing an ejected volume or a removed folder.
    func makeItem(id: FileItem.ID, kind forcedKind: ItemKind? = nil) throws -> FileItem {
        let url = url(of: id)
        let values = try url.resourceValues(forKeys: Self.resourceKeys)
        let kind =
            forcedKind
            ?? kind(of: id, values: values, isVolumeRoot: id.rawValue == values.volume?.path)
        var item = FileItem(
            id: id,
            name: name(of: id, kind: kind, values: values),
            kind: kind,
            parentID: parentID(of: id, kind: kind),
            volume: VolumeID(values.volume?.path ?? "/"),
            modified: values.contentModificationDate,
            size: values.isRegularFile == true ? values.fileSize.map(Int64.init) : nil,
            kindDescription: values.localizedTypeDescription,
            isHidden: values.isHidden ?? lastComponent(of: id).hasPrefix("."))
        item.isEjectable = kind == .volume && Self.isEjectable(url)
        item.isOnlyOnline = !kind.isContainer && isInCloudFolder(id) && locations.isOnlyOnline(url)
        return item
    }

    /// A volume is in This Mac (ADR 0044), unless the user added it as a
    /// folder (ADR 0045); a boundary folder has no enclosing folder the app may show.
    private func parentID(of id: FileItem.ID, kind: ItemKind) -> FileItem.ID? {
        if isAddedFolder(id) { return nil }
        if kind == .volume { return .computer }
        return isBoundaryRoot(id) ? nil : Self.ancestry(id).first
    }

    /// Whether a volume can be ejected: one macOS calls ejectable or
    /// removable, never the startup disk.
    private static func isEjectable(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [
            .volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsRootFileSystemKey,
        ])
        guard let values, values.volumeIsRootFileSystem != true else { return false }
        return values.volumeIsEjectable == true || values.volumeIsRemovable == true
    }

    private func childID(of folder: FileItem.ID, named name: String) -> FileItem.ID {
        FileItem.ID(folder.rawValue == "/" ? "/" + name : folder.rawValue + "/" + name)
    }

    private func kind(of id: FileItem.ID, values: URLResourceValues, isVolumeRoot: Bool) -> ItemKind
    {
        if values.isSymbolicLink == true { return .file }
        if values.isPackage == true { return .package }
        guard values.isDirectory == true else { return .file }
        if isVolumeRoot { return .volume }
        if isCloudFolder(id) { return .cloud }
        if id == homeFolder { return .home }
        return .folder
    }

    private func name(of id: FileItem.ID, kind: ItemKind, values: URLResourceValues) -> String {
        // An added folder goes by the name the Files app shows: iCloud Drive
        // rather than the name of its folder in the container.
        if isAddedFolder(id), let localizedName = values.localizedName { return localizedName }
        return switch kind {
        case .volume: values.volumeLocalizedName ?? lastComponent(of: id)
        case .cloud:
            id == iCloudDrive
                ? Locations.iCloudDriveName : Locations.cloudName(ofFolder: lastComponent(of: id))
        case .computer: FileItem.computer().name
        case .folder, .file, .package, .home: lastComponent(of: id)
        }
    }

    /// Whether an item is a cloud folder or inside one (ADR 0049).
    public func isInCloudFolder(_ id: FileItem.ID) -> Bool {
        isCloudFolder(id) || Self.ancestry(id).contains(where: isCloudFolder)
    }

    /// Whether a folder belongs to a cloud service (ADR 0049).
    private func isCloudFolder(_ id: FileItem.ID) -> Bool {
        fixedCloudFolders.contains(id) || Self.ancestry(id).first == cloudStorage
    }

    /// Whether an item is one of the boundary's folders, which have no
    /// enclosing folder the app may show.
    private func isBoundaryRoot(_ id: FileItem.ID) -> Bool {
        locations.boundary?.contains { $0.standardizedFileURL.path == id.rawValue } ?? false
    }

    /// Whether an item is one of the folders the user added (ADR 0045).
    private func isAddedFolder(_ id: FileItem.ID) -> Bool {
        locations.addedFolders.contains { $0.standardizedFileURL.path == id.rawValue }
    }

    private func lastComponent(of id: FileItem.ID) -> String {
        id.rawValue.split(separator: "/").last.map(String.init) ?? "/"
    }

    private static func fileSystemError(_ error: any Error, for id: FileItem.ID) -> any Error {
        guard let cocoa = error as? CocoaError else { return error }
        switch cocoa.code {
        case .fileReadNoSuchFile, .fileNoSuchFile: return FileSystemError.notFound(id)
        case .fileReadNoPermission: return FileSystemError.notReadable(id)
        default: return error
        }
    }
}
