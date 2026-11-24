import Foundation
import UniformTypeIdentifiers

/// What Treewise's own icon of a file shows on the iPad and the iPhone (ADR 0151): its
/// kind, which gives the colour, and its extension in capitals, from its name alone.
public struct FileBadge: Equatable, Sendable {
    /// The kinds of file the icons tell apart by colour.
    public enum Kind: Sendable, CaseIterable {
        case pdf, document, spreadsheet, presentation, image, movie, audio, archive, code
        case text, other
    }

    /// The longest extension the icon shows; a longer one would not fit its band.
    public static let longestLabel = 4

    /// The office formats by extension: their types also conform to zip, and a few have
    /// no type of their own on every system.
    private static let officeKinds: [String: Kind] = [
        "doc": .document, "docx": .document, "pages": .document, "rtf": .document,
        "odt": .document,
        "xls": .spreadsheet, "xlsx": .spreadsheet, "numbers": .spreadsheet,
        "csv": .spreadsheet, "tsv": .spreadsheet, "ods": .spreadsheet,
        "ppt": .presentation, "pptx": .presentation, "key": .presentation,
        "odp": .presentation,
    ]

    /// The kinds that follow from a type's conformance, the first match counting.
    private static let typeKinds: [(UTType, Kind)] = [
        (.pdf, .pdf), (.spreadsheet, .spreadsheet), (.presentation, .presentation),
        (.image, .image), (.movie, .movie), (.video, .movie), (.audio, .audio),
        (.archive, .archive), (.sourceCode, .code), (.text, .text),
    ]

    public let kind: Kind
    /// The extension in capitals, or nil when there is none or it is too long to show.
    public let label: String?

    /// The badge of a file called `fileName`.
    public init(fileName: String) {
        let pathExtension = (fileName as NSString).pathExtension.lowercased()
        kind = Self.kind(of: pathExtension)
        label =
            pathExtension.isEmpty || pathExtension.count > Self.longestLabel
            ? nil : pathExtension.uppercased()
    }

    private static func kind(of pathExtension: String) -> Kind {
        if let kind = officeKinds[pathExtension] { return kind }
        guard !pathExtension.isEmpty, let type = UTType(filenameExtension: pathExtension)
        else { return .other }
        return typeKinds.first { type.conforms(to: $0.0) }?.1 ?? .other
    }
}
