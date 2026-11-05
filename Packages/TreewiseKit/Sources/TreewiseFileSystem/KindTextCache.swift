import Foundation

/// The system's kind text (`localizedTypeDescription`) per kind of item in one
/// folder. Reading it costs about 20 µs per file, while items with the same
/// extension and the same shape (folder, package, symlink) share it, so it is
/// read once per such group (ADR 0016).
struct KindTextCache {
    private var texts: [String: String] = [:]

    /// Returns the kind text of `url`, read from disk the first time a group is
    /// seen. Items without an extension are read one by one, because their
    /// kind depends on their contents.
    mutating func text(for url: URL, values: URLResourceValues) -> String? {
        let pathExtension = url.pathExtension.lowercased()
        guard !pathExtension.isEmpty || values.isDirectory == true else { return read(url) }
        let group =
            [
                values.isSymbolicLink == true, values.isPackage == true, values.isDirectory == true,
            ].map { $0 ? "1" : "0" }.joined() + pathExtension
        if let text = texts[group] { return text }
        let text = read(url)
        texts[group] = text
        return text
    }

    private func read(_ url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey]))?.localizedTypeDescription
    }
}
