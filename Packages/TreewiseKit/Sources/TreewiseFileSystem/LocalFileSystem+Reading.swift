import Foundation
import TreewiseCore
import os

/// Reading a folder's items (ADR 0016), timed in the log (ADR 0121).
extension LocalFileSystem {
    /// Logs at debug level how long reading a folder took, and in which part.
    static let logger = Logger(subsystem: LogSubsystem.name, category: "reading")

    public func contents(of folder: FileItem.ID) async throws -> [FileItem] {
        if folder == .computer { return try await locations() }
        try checkBoundary(folder)
        if let place = ArchivePath(folder) { return try await archiveContents(of: place) }
        let clock = ContinuousClock()
        let started = clock.now
        let urls: [URL]
        let asksCloudStatus = isInCloudFolder(folder)
        // In a cloud folder whether a file is only online is read with the listing, not
        // once more for each file.
        let keys = asksCloudStatus ? Self.cloudListingKeys : Self.listingKeys
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: url(of: folder), includingPropertiesForKeys: Array(keys))
        } catch {
            throw FileSystemError.mapping(error, for: folder)
        }
        let listed = clock.now
        var reading = Reading(folder: folder, asksCloudStatus: asksCloudStatus)
        reading.volume = try? url(of: folder).resourceValues(forKeys: [.volumeURLKey]).volume
        // An entry that disappears between listing and reading is left out.
        let items = urls.compactMap { item(at: $0, in: &reading) }
        Self.logger.debug(
            """
            Read \(items.count) items of \(folder.rawValue, privacy: .private): listing \
            \(listed - started), items \(clock.now - listed), of which status \
            \(reading.statusTime)
            """)
        return items
    }

    /// What reading a folder's items shares between them.
    private struct Reading {
        let folder: FileItem.ID
        /// Whether the folder is in the cloud, where files may be only online.
        let asksCloudStatus: Bool
        var volume: URL?
        var kindTexts = KindTextCache()
        /// The time spent reading whether files are only online, for the log.
        var statusTime = Duration.zero
    }

    /// The item a listed entry is, or nil for Treewise's own temporary items and an entry
    /// gone since it was listed.
    private func item(at child: URL, in reading: inout Reading) -> FileItem? {
        let fileName = child.lastPathComponent
        guard !Self.temporaryPrefixes.contains(where: fileName.hasPrefix) else { return nil }
        let id = childID(of: reading.folder, named: fileName)
        guard let values = try? child.resourceValues(forKeys: Self.listingKeys) else {
            return nil
        }
        // A mount point is on a volume of its own: read it in full.
        if values.isVolume == true { return try? makeItem(id: id) }
        let kind = kind(of: id, values: values, isVolumeRoot: false)
        var item = FileItem(
            id: id, name: name(of: id, kind: kind, values: values), kind: kind,
            parentID: reading.folder, volume: VolumeID(reading.volume?.path ?? "/"),
            modified: values.contentModificationDate,
            size: values.isRegularFile == true ? values.fileSize.map(Int64.init) : nil,
            kindDescription: reading.kindTexts.text(for: child, values: values),
            isHidden: values.isHidden ?? fileName.hasPrefix("."))
        if reading.asksCloudStatus, !kind.isContainer {
            let clock = ContinuousClock()
            let started = clock.now
            item.isOnlyOnline = locations.isOnlyOnline(child)
            reading.statusTime += clock.now - started
        }
        return item
    }
}
