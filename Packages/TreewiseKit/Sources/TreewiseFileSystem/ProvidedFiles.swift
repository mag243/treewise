import Foundation
import TreewiseCore
import UniformTypeIdentifiers
import os

/// Files another app offers in a drop, as item providers (ADR 0020, 0047): each is copied
/// into a folder of its own in an inbox, so two files of one name both arrive, and the
/// caller copies them out with the drag rules and removes the inbox. Only a provider with a
/// named file counts; a piece of text or a link is no file.
public enum ProvidedFiles {
    private static let logger = Logger(subsystem: LogSubsystem.name, category: "drops")

    /// Copies each provider's file into `inbox`, and returns where they arrived, in order;
    /// a file that cannot be read is left out.
    ///
    /// Precondition: `inbox` is an empty folder, as `PromiseInbox.make(in:)` makes.
    /// It runs on the main actor, where a drop hands over its providers; each file is
    /// copied in the provider's own callback, off it.
    @MainActor
    public static func receive(_ providers: [NSItemProvider], into inbox: URL) async -> [URL] {
        var received: [URL] = []
        for (index, provider) in providers.enumerated() {
            let folder = inbox.appendingPathComponent("\(index)", isDirectory: true)
            if let url = await receive(provider, into: folder) { received.append(url) }
        }
        return received
    }

    @MainActor
    private static func receive(_ provider: NSItemProvider, into folder: URL) async -> URL? {
        let types = provider.registeredTypeIdentifiers
        if types.contains(UTType.fileURL.identifier) {
            return await copy(fileURLOf: provider, into: folder)
        }
        // A file comes with its name; a piece of text or a link has none.
        guard let name = provider.suggestedName,
            let type = types.compactMap(UTType.init).first(where: {
                $0.conforms(to: .item) && !$0.conforms(to: .url)
            })
        else { return nil }
        return await copy(type, of: provider, named: name, into: folder)
    }

    /// Copies the file a provider names by its URL, keeping its name.
    @MainActor
    private static func copy(fileURLOf provider: NSItemProvider, into folder: URL) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url else {
                    logger.error("An offered file did not arrive: \(String(describing: error))")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: keep(url, as: url.lastPathComponent, in: folder))
            }
        }
    }

    /// Copies a provider's file of `type`, named as the provider says with the type's extension.
    @MainActor
    private static func copy(
        _ type: UTType, of provider: NSItemProvider, named name: String, into folder: URL
    ) async -> URL? {
        let fileName =
            (name as NSString).pathExtension.isEmpty
            ? type.preferredFilenameExtension.map { name + "." + $0 } ?? name : name
        return await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                // The file is the provider's only until this returns, so it is copied here.
                guard let url else {
                    logger.error("An offered file did not arrive: \(String(describing: error))")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: keep(url, as: fileName, in: folder))
            }
        }
    }

    private static func keep(_ url: URL, as name: String, in folder: URL) -> URL? {
        let destination = folder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: destination)
            return destination
        } catch {
            logger.error("An offered file could not be kept: \(error)")
            return nil
        }
    }
}
