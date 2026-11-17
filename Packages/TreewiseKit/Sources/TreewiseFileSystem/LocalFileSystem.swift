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
    /// and the same for most items of a folder (ADR 0016), and without whether it is a
    /// package, which only a folder can be and which a cloud provider is slow to
    /// answer for each file (ADR 0126).
    static let listingKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isVolumeKey,
        .contentModificationDateKey, .fileSizeKey, .isHiddenKey,
    ]

    /// The resource values read for a folder of a listing: also whether it is a package.
    static let folderListingKeys = listingKeys.union([.isPackageKey])

    /// The resource values read for each item of a cloud folder: on the Mac also whether
    /// it is kept only online (ADR 0051); the iPad reads that from the dataless flag
    /// instead, as the provider is slow to answer for each file (ADR 0126).
    #if os(macOS)
        static let cloudListingKeys = listingKeys.union([.ubiquitousItemDownloadingStatusKey])
    #else
        static let cloudListingKeys = listingKeys
    #endif

    /// The names Treewise gives its own temporary items: partial copies
    /// (ADR 0018) and inboxes of promised files (ADR 0020). They are never listed.
    static let temporaryPrefixes = [FileCopier.partialPrefix, PromiseInbox.prefix]

    /// Where the sidebar's folders and volumes are.
    public let locations: Locations
    #if os(macOS)
        /// The listings of the archives shown (ADR 0076).
        let archiveCatalog = ArchiveCatalog()
    #endif
    /// The cloud folders at a fixed place, read once: listing a folder asks for
    /// each of its subfolders whether it is one.
    private let fixedCloudFolders: Set<FileItem.ID>
    /// The folder whose subfolders are cloud folders.
    private let cloudStorage: FileItem.ID
    /// The user's home folder.
    private let homeFolder: FileItem.ID
    /// The folder holding iCloud Drive's files, which goes by a name of its own.
    private let iCloudDrive: FileItem.ID
    /// The paths of the folders the user added, read once: listing a folder asks for
    /// each of its items whether it is one.
    private let addedFolderPaths: Set<String>
    /// The names the user gave added folders (ADR 0119).
    private let addedFolderLabels: [FileItem.ID: String]
    /// The paths of the boundary's folders, read once, or nil without a boundary.
    private let boundaryPaths: Set<String>?

    /// Creates a provider for the local disk. Folders list their hidden items
    /// too, marked `isHidden`; whether they show is the window's setting (ADR 0023).
    public init(locations: Locations = .system) {
        self.locations = locations
        homeFolder = Self.identity(of: locations.home)
        iCloudDrive = Self.identity(of: locations.iCloudDrive)
        fixedCloudFolders = Set(
            ([locations.iCloudDrive] + locations.syncFolders
                + locations.addedFolders.filter(locations.isInCloud)).map(Self.identity))
        cloudStorage = Self.identity(of: locations.cloudStorage)
        addedFolderPaths = Set(locations.addedFolders.map(\.standardizedFileURL.path))
        addedFolderLabels = Dictionary(
            locations.labels.map { (Self.identity(of: $0.key), $0.value) },
            uniquingKeysWith: { first, _ in first })
        boundaryPaths = locations.boundary.map { Set($0.map(\.standardizedFileURL.path)) }
    }

    /// The identities of the folders containing a path, nearest first, derived
    /// from the path alone without reading the disk.
    public static func ancestry(_ id: FileItem.ID) -> [FileItem.ID] {
        if let place = ArchivePath(id) { return [place.parent] + ancestry(place.parent) }
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
        guard id != .computer, let boundaryPaths else { return true }
        return boundaryPaths.contains { rootPath in
            id.rawValue == rootPath || id.rawValue.hasPrefix(rootPath + "/")
        }
    }

    /// - Throws: `FileSystemError.outsideBoundary` when `id` is outside the boundary.
    public func checkBoundary(_ id: FileItem.ID) throws {
        guard isInsideBoundary(id) else { throw FileSystemError.outsideBoundary(id) }
    }

    public func item(at id: FileItem.ID) async throws -> FileItem {
        if let place = ArchivePath(id) {
            try checkBoundary(id)
            return try await archiveItem(at: place)
        }
        return try currentItem(at: id)
    }

    /// Reads an item without suspending, for callers that must answer at once,
    /// such as AppKit asking what a drop would do while the pointer moves.
    public func currentItem(at id: FileItem.ID) throws -> FileItem {
        if id == .computer { return .computer() }
        try checkBoundary(id)
        if let place = ArchivePath(id) { return try currentArchiveItem(at: place) }
        do {
            return try makeItem(id: id)
        } catch {
            throw FileSystemError.mapping(error, for: id)
        }
    }

    public func availableCapacity(of folder: FileItem.ID) async throws -> Int64? {
        if folder == .computer || folder.isInsideArchive { return nil }
        try checkBoundary(folder)
        let values: URLResourceValues
        do {
            values = try url(of: folder).resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
            ])
        } catch {
            throw FileSystemError.mapping(error, for: folder)
        }
        return values.volumeAvailableCapacityForImportantUsage
            ?? values.volumeAvailableCapacity.map(Int64.init)
    }

    /// A folder on a local volume, outside cloud folders and archives, reads quickly
    /// (ADR 0108); a network volume, a cloud folder or a File Provider does not.
    public func readsQuickly(_ folder: FileItem.ID) -> Bool {
        guard folder != .computer, !folder.isInsideArchive, !isInCloudFolder(folder) else {
            return false
        }
        let values = try? url(of: folder).resourceValues(forKeys: [.volumeIsLocalKey])
        return values?.volumeIsLocal == true
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

    func childID(of folder: FileItem.ID, named name: String) -> FileItem.ID {
        FileItem.ID(folder.rawValue == "/" ? "/" + name : folder.rawValue + "/" + name)
    }

    func kind(of id: FileItem.ID, values: URLResourceValues, isVolumeRoot: Bool) -> ItemKind {
        if values.isSymbolicLink == true { return .file }
        if values.isPackage == true { return .package }
        guard values.isDirectory == true else { return .file }
        if isVolumeRoot { return .volume }
        if isCloudFolder(id) { return .cloud }
        if id == homeFolder { return .home }
        return .folder
    }

    func name(of id: FileItem.ID, kind: ItemKind, values: URLResourceValues) -> String {
        // An added folder goes by the name the user gave it (ADR 0119), else by the
        // name the Files app shows: iCloud Drive rather than the name of its folder in
        // the container.
        if let label = addedFolderLabels[id] { return label }
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
        boundaryPaths?.contains(id.rawValue) ?? false
    }

    /// Whether an item is one of the folders the user added (ADR 0045).
    private func isAddedFolder(_ id: FileItem.ID) -> Bool {
        addedFolderPaths.contains(id.rawValue)
    }

    private func lastComponent(of id: FileItem.ID) -> String {
        id.rawValue.split(separator: "/").last.map(String.init) ?? "/"
    }
}
