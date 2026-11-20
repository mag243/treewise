import Foundation

/// A template's file: JSON with its format's number, so a later Treewise can change the
/// format and still read this one (ADR 0091).
public enum FolderTemplateFile {
    /// The format this Treewise writes and the newest it reads.
    public static let format = 1
    /// The extension of a template's file.
    public static let pathExtension = "json"

    /// Why a file cannot be read as a template.
    public enum Problem: Error, Hashable, Sendable {
        /// The file is no template, or is damaged.
        case unreadable
        /// The file was written by a later Treewise in a format this one does not know.
        case newerFormat
        /// The file's folders cannot be made.
        case folders(FolderTree.Problem)
        /// The file was read, but the template could not be kept.
        case notSaved
    }

    private struct Envelope: Codable {
        let format: Int
        /// The template's id, so another Mac can find the same template (ADR 0141); a file
        /// written before held none, and a Treewise before reads past it.
        let id: String?
        let name: String
        let root: FolderTree
    }

    private struct Identity: Decodable {
        let id: String?
    }

    private struct Version: Decodable {
        let format: Int
    }

    /// The file of `template`.
    public static func data(of template: FolderTemplate) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(
            Envelope(format: format, id: template.id, name: template.name, root: template.root))
    }

    /// The id the file holds, or nil for a file written without one or no template.
    public static func id(in data: Data) -> String? {
        (try? JSONDecoder().decode(Identity.self, from: data))?.id
    }

    /// The template in a file, checked as a template (ADR 0096), with the id it is kept
    /// under, whatever id the file holds.
    public static func template(from data: Data, id: String) throws(Problem) -> FolderTemplate {
        let decoder = JSONDecoder()
        guard let version = try? decoder.decode(Version.self, from: data) else {
            throw .unreadable
        }
        guard version.format <= format else { throw .newerFormat }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
            !envelope.name.trimmingCharacters(in: .whitespaces).isEmpty
        else { throw .unreadable }
        do {
            try envelope.root.checkTemplate()
        } catch {
            throw .folders(error)
        }
        return FolderTemplate(id: id, name: envelope.name, root: envelope.root)
    }
}
