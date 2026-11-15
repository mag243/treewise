import AppKit
import QuickLookThumbnailing
import TreewiseCore
import TreewiseUI

/// Thumbnails for the icon view, made in the background by Quick Look and kept by path and
/// modification date, so a changed file gets a new one (ADR 0025). Folders and packages
/// keep their workspace icon. A thumbnail being made is asked for once, whoever waits for
/// it; one no tile waits for any more is cancelled; and the cache holds at most
/// `costLimit` bytes of pixels.
@MainActor
final class ThumbnailCache {
    /// How many thumbnails are kept; the cache lets the oldest go first.
    private static let limit = 2_000
    /// How many bytes of pixels the thumbnails kept may take.
    private static let costLimit = 64 * 1_024 * 1_024
    private static let bytesPerPixel = 4

    /// A thumbnail being made, and who waits for it, by the tile that asked.
    private struct Making {
        let request: QLThumbnailGenerator.Request
        /// Which request this is, as a cancelled one for the same file may still end.
        let token: UUID
        var waiting: [ObjectIdentifier: @MainActor (NSImage) -> Void]
    }

    private let cache = NSCache<NSString, NSImage>()
    private var making: [String: Making] = [:]
    /// The thumbnail each tile waits for, by its key.
    private var asked: [ObjectIdentifier: String] = [:]

    init() {
        cache.countLimit = Self.limit
        cache.totalCostLimit = Self.costLimit
    }

    /// The thumbnail made earlier for the item as it is now, if any.
    func cached(_ item: FileItem) -> NSImage? {
        cache.object(forKey: key(of: item) as NSString)
    }

    /// Makes a thumbnail of a file in the background and gives it to `done` on the main
    /// actor; nothing happens when Quick Look has none. `owner` waits for it, as a tile
    /// does, and asks for nothing else meanwhile: a new request from it, or `cancel`, ends
    /// its wait for the one before.
    func make(
        _ item: FileItem, size: NSSize, scale: CGFloat, for owner: AnyObject,
        done: @escaping @MainActor (NSImage) -> Void
    ) {
        guard item.kind == .file, let file = item.id.diskURL else { return }
        let key = key(of: item)
        let tile = ObjectIdentifier(owner)
        if asked[tile] != key { cancel(for: owner) }
        asked[tile] = key
        if making[key] != nil {
            making[key]?.waiting[tile] = done
            return
        }
        let request = QLThumbnailGenerator.Request(
            fileAt: file, size: size, scale: scale, representationTypes: .thumbnail)
        let token = UUID()
        making[key] = Making(request: request, token: token, waiting: [tile: done])
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            let image = thumbnail?.cgImage
            Task { @MainActor in self.finish(key, token: token, image: image, size: size) }
        }
    }

    /// Ends `owner`'s wait; a thumbnail no one waits for any more is cancelled.
    func cancel(for owner: AnyObject) {
        let tile = ObjectIdentifier(owner)
        guard let key = asked.removeValue(forKey: tile) else { return }
        making[key]?.waiting[tile] = nil
        guard let left = making[key], left.waiting.isEmpty else { return }
        making[key] = nil
        QLThumbnailGenerator.shared.cancel(left.request)
    }

    /// Hands a thumbnail to those who wait for it. A cancelled request may still end
    /// after a new one for the same file started; it then leaves the new one alone.
    private func finish(_ key: String, token: UUID, image: CGImage?, size: NSSize) {
        guard let done = making[key], done.token == token else { return }
        making[key] = nil
        for tile in done.waiting.keys where asked[tile] == key { asked[tile] = nil }
        guard let image else { return }
        let thumbnail = NSImage(cgImage: image, size: size)
        cache.setObject(
            thumbnail, forKey: key as NSString,
            cost: image.width * image.height * Self.bytesPerPixel)
        for show in done.waiting.values { show(thumbnail) }
    }

    private func key(of item: FileItem) -> String {
        "\(item.id.rawValue)|\(item.modified?.timeIntervalSinceReferenceDate ?? 0)"
    }
}
