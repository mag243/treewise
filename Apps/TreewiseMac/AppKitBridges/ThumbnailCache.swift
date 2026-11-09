import AppKit
import QuickLookThumbnailing
import TreewiseCore
import TreewiseUI

/// Thumbnails for the icon view, made in the background by Quick Look and
/// kept by path and modification date, so a changed file gets a new one
/// (ADR 0025). Folders and packages keep their workspace icon.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    /// How many thumbnails are kept; the cache lets the oldest go first.
    private static let limit = 2_000

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = Self.limit
    }

    /// The thumbnail made earlier for the item as it is now, if any.
    func cached(_ item: FileItem) -> NSImage? {
        cache.object(forKey: key(of: item) as NSString)
    }

    /// Makes a thumbnail of a file in the background and gives it to `done`
    /// on the main actor; nothing happens when Quick Look has none.
    func make(
        _ item: FileItem, size: NSSize, scale: CGFloat,
        done: @escaping @MainActor (NSImage) -> Void
    ) {
        guard item.kind == .file, let file = item.id.diskURL else { return }
        let key = key(of: item)
        let request = QLThumbnailGenerator.Request(
            fileAt: file, size: size, scale: scale,
            representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            guard let image = thumbnail?.cgImage else { return }
            Task { @MainActor in
                let thumbnail = NSImage(cgImage: image, size: size)
                self.cache.setObject(thumbnail, forKey: key as NSString)
                done(thumbnail)
            }
        }
    }

    private func key(of item: FileItem) -> String {
        "\(item.id.rawValue)|\(item.modified?.timeIntervalSinceReferenceDate ?? 0)"
    }
}
