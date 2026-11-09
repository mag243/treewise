import Foundation
import TreewiseCore

extension LocalFileSystem {
    /// Where the sidebar's favorites and locations are. Tests point every
    /// folder into a temporary directory (ADR 0016).
    public struct Locations: Sendable {
        /// The name the sidebar shows for iCloud Drive.
        static let iCloudDriveName = "iCloud Drive"

        /// The user's home folder.
        public var home: URL
        /// The Applications folder.
        public var applications: URL
        /// Returns the URLs of the mounted volumes, startup volume first.
        public var mountedVolumes: @Sendable () -> [URL]
        /// The folders the app is confined to, such as the sandbox volumes
        /// (ADR 0019); `nil` for the whole disk.
        public var boundary: [URL]?
        /// The folders the user added through the document picker on iOS
        /// (ADR 0045), listed as Locations after the volumes; each has no
        /// enclosing folder.
        public var addedFolders: [URL]
        /// Whether a file is kept only online; asked only inside a cloud folder.
        public var isOnlyOnline: @Sendable (URL) -> Bool
        /// What moves the original of a changed archive to the Trash (ADR 0078).
        public var moveToTrash: @Sendable (URL) throws -> Void

        /// Creates the set of folders, the source of mounted volumes and the boundary.
        public init(
            home: URL, applications: URL,
            mountedVolumes: @escaping @Sendable () -> [URL] = Locations.systemVolumes,
            boundary: [URL]? = nil, addedFolders: [URL] = [],
            isOnlyOnline: @escaping @Sendable (URL) -> Bool = Locations.systemIsOnlyOnline,
            moveToTrash: @escaping @Sendable (URL) throws -> Void = Locations.systemMoveToTrash
        ) {
            self.home = home
            self.applications = applications
            self.mountedVolumes = mountedVolumes
            self.boundary = boundary
            self.addedFolders = addedFolders
            self.isOnlyOnline = isOnlyOnline
            self.moveToTrash = moveToTrash
        }

        /// Moves a file to the Trash of its volume.
        public static func systemMoveToTrash(_ file: URL) throws {
            _ = try TrashService().trash(FileItem.ID(file.path))
        }

        /// What macOS reports: a file not downloaded is only online (ADR 0051).
        /// Reading it does not download the file.
        /// Where the copies of entries of archives are kept (ADR 0076).
        public var archiveCacheFolder: URL {
            home.appendingPathComponent("Library/Caches/me.m-domain.treewise/Archives")
        }

        public static func systemIsOnlyOnline(_ url: URL) -> Bool {
            let values = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            return values?.ubiquitousItemDownloadingStatus == .notDownloaded
        }

        /// Only the folders the user added (ADR 0045): they are the Locations
        /// and the boundary, without volumes; `home` gives no favorites, as
        /// it is outside them.
        public static func added(_ folders: [URL], home: URL) -> Locations {
            Locations(
                home: home, applications: home.appendingPathComponent("Applications"),
                mountedVolumes: { [] }, boundary: folders, addedFolders: folders)
        }

        /// The real home folder, Applications and mounted volumes.
        public static let system = Locations(
            home: URL.homeDirectory,
            applications: URL(fileURLWithPath: "/Applications"))

        /// The volumes the system has mounted, without hidden ones, from the
        /// kernel's mount table (ADR 0046); none on iOS, whose locations come
        /// from bookmarks (PLAN.md §6).
        public static func systemVolumes() -> [URL] {
            MountTable.mountPoints()
        }

        /// Those of `volumes` that are mounted, in the order given: a volume
        /// whose mount point is left behind empty is not one of them.
        public static func systemVolumes(among volumes: [URL]) -> [URL] {
            let mounted = Set(MountTable.mountPoints(includingHidden: true).map(\.path))
            return volumes.filter { mounted.contains($0.resolvingSymlinksInPath().path) }
        }

        /// The iCloud Drive folder inside the home folder.
        var iCloudDrive: URL {
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        }

        /// The folder where macOS keeps the folders of File Provider apps:
        /// Dropbox, Nextcloud, OneDrive and others (ADR 0049).
        var cloudStorage: URL {
            home.appendingPathComponent("Library/CloudStorage")
        }

        /// Where cloud services without a File Provider keep their folder.
        var syncFolders: [URL] {
            ["Dropbox", "Nextcloud"].map(home.appendingPathComponent)
        }

        /// The name the sidebar shows for a cloud folder: `Provider-account`
        /// becomes `Provider - account`, so two accounts stay apart (ADR 0049).
        static func cloudName(ofFolder folder: String) -> String {
            guard let separator = folder.firstIndex(of: "-") else { return folder }
            let account = folder[folder.index(after: separator)...]
            return "\(folder[..<separator]) - \(account)"
        }

        /// The favorite folders, in the order the sidebar shows them (as in the prototype).
        var favorites: [URL] {
            [applications]
                + ["Desktop", "Documents", "Downloads", "Pictures"].map(home.appendingPathComponent)
        }
    }

    /// The mounted volumes, the added folders that exist, the home folder
    /// inside the boundary, iCloud Drive when it exists, then the other cloud
    /// folders by name (ADR 0049).
    public func locations() async throws -> [FileItem] {
        let volumes = locations.mountedVolumes().compactMap { url in
            try? makeItem(id: id(of: url), kind: .volume)
        }
        let added = locations.addedFolders.compactMap { url in
            try? makeItem(id: id(of: url))
        }
        let iCloud = locations.iCloudDrive
        let cloud = try? makeItem(id: id(of: iCloud), kind: .cloud)
        let homeID = id(of: locations.home)
        let home = isInsideBoundary(homeID) ? try? makeItem(id: homeID) : nil
        return volumes + added + [home, cloud].compactMap { $0 } + otherCloudFolders()
    }

    /// The cloud folders that exist inside the boundary, without iCloud Drive
    /// and sorted by name. A symlink reads as a file, so it is left out.
    private func otherCloudFolders() -> [FileItem] {
        let inStorage = try? FileManager.default.contentsOfDirectory(
            at: locations.cloudStorage, includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles)
        return (locations.syncFolders + (inStorage ?? []))
            .compactMap { url in
                let id = id(of: url)
                return isInsideBoundary(id) ? try? makeItem(id: id) : nil
            }
            .filter { $0.kind == .cloud }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The favorite folders that exist inside the boundary.
    public func favorites() async throws -> [FileItem] {
        locations.favorites.compactMap { url in
            let id = id(of: url)
            return isInsideBoundary(id) ? try? makeItem(id: id) : nil
        }
    }

    func id(of url: URL) -> FileItem.ID {
        Self.identity(of: url)
    }

    /// An item's identity: its standardized path without a trailing slash (ADR 0016).
    static func identity(of url: URL) -> FileItem.ID {
        let path = url.standardizedFileURL.path
        return FileItem.ID(path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path)
    }
}

#if os(macOS)
    extension LocalFileSystem: VolumeEjecting {
        /// Unmounts the volume and ejects its disk, without macOS's own alerts:
        /// the app shows the failure (ADR 0044).
        public func eject(_ volume: FileItem.ID) async throws {
            do {
                try await FileManager.default.unmountVolume(
                    at: url(of: volume), options: [.allPartitionsAndEjectDisk, .withoutUI])
            } catch {
                throw FileSystemError.notEjected(volume, error.localizedDescription)
            }
        }
    }
#endif
