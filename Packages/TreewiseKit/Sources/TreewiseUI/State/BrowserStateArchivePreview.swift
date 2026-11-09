import Foundation
import TreewiseCore

/// Getting a file out of an archive for what needs one on disk (ADR 0076).
extension BrowserState {
    /// The files to preview or open for `items`: where they are on disk, or a
    /// copy of an entry of an archive. An entry that cannot be read is left
    /// out and shown as the window's failure.
    public func previewURLs(for items: [FileItem]) async -> [URL] {
        var urls: [URL] = []
        for item in items {
            if let url = item.id.diskURL {
                urls.append(url)
                continue
            }
            do {
                if let copy = try await archives?.cachedCopy(of: item) { urls.append(copy) }
            } catch {
                failure = error as? FileSystemError ?? .unexpected(error.localizedDescription)
            }
        }
        return urls
    }

    /// Copies an entry of an archive to a file, for a drop in another app.
    ///
    /// - Throws: what copying it out throws.
    public func copyOut(_ entry: FileItem, toFileAt url: URL) async throws {
        guard let operations else { throw FileSystemError.notReadable(entry.id) }
        let folder = FileItem.ID(url.deletingLastPathComponent().standardizedFileURL.path)
        _ = try await operations.copy(entry, into: folder, as: url.lastPathComponent)
    }
}
