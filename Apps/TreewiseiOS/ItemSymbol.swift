import TreewiseCore
import UniformTypeIdentifiers

/// The SF Symbol of an item in the iPad's lists, by its kind and, for a
/// file, its type.
enum ItemSymbol {
    static func name(for item: FileItem) -> String {
        switch item.kind {
        case .folder: return "folder"
        case .home: return "house"
        case .volume: return "externaldrive"
        case .cloud: return "icloud"
        case .computer: return "ipad"
        case .package: return "shippingbox"
        case .file: return fileSymbol(for: item)
        }
    }

    private static func fileSymbol(for item: FileItem) -> String {
        let pathExtension = (item.name as NSString).pathExtension
        guard let type = UTType(filenameExtension: pathExtension) else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return "film" }
        if type.conforms(to: .audio) { return "music.note" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        if type.conforms(to: .archive) { return "doc.zipper" }
        if type.conforms(to: .sourceCode) { return "chevron.left.forwardslash.chevron.right" }
        if type.conforms(to: .text) { return "doc.text" }
        return "doc"
    }
}
