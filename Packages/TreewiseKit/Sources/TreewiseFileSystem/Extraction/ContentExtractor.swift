import Foundation
import TreewiseModuleInterface
import UniformTypeIdentifiers
import os

/// Reads what a module may see of a file the user chose, on the device (ADR 0057).
/// It reads one file per call and never walks a folder. What it cannot read gives
/// an empty result and no error, because a module can still work from names.
///
/// Reading is slow for a scan: call it away from the main actor.
public struct ContentExtractor: Sendable {
    /// The most characters of text a module receives from one file.
    public static let maximumTextLength = 200_000
    /// The most pages read for text from one file.
    public static let maximumPages = 20
    /// The most page images a module receives from one file: they are large.
    public static let maximumPageImages = 5
    /// The longest side of an image a module receives, in pixels.
    public static let maximumImageDimension = 1600
    /// The most bytes read of a plain text file. UTF-8 takes up to four per character.
    private static let maximumPlainTextBytes = maximumTextLength * 4

    private static let logger = Logger(
        subsystem: "me.m-domain.treewise", category: "ContentExtractor")

    /// Creates an extractor.
    public init() {}

    /// Returns the content of the given kinds from the file at `url`.
    ///
    /// Postcondition: the result holds only `kinds`, within this type's limits.
    public func content(of url: URL, kinds: Set<ModuleContentKind>) -> ModuleContent {
        guard !kinds.isEmpty,
            let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey]),
            values.isRegularFile == true, let type = values.contentType
        else { return ModuleContent() }
        if type.conforms(to: .pdf) { return pdfContent(of: url, kinds: kinds) }
        if type.conforms(to: .image) { return imageContent(of: url, kinds: kinds) }
        if type.conforms(to: .text), kinds.contains(.text) {
            return ModuleContent(text: plainText(of: url))
        }
        return ModuleContent()
    }

    private func plainText(of url: URL) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: Self.maximumPlainTextBytes) ?? Data()
            // swiftlint:disable:next optional_data_string_conversion - a file may hold invalid bytes, and the read may cut a character
            let text = String(decoding: data, as: UTF8.self)
            return String(text.prefix(Self.maximumTextLength))
        } catch {
            Self.logger.error("Reading text failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func pdfContent(of url: URL, kinds: Set<ModuleContentKind>) -> ModuleContent {
        guard let pdf = PDFExtraction(url: url) else { return ModuleContent() }
        let wantsText = !kinds.isDisjoint(with: [.text, .positionedText])
        let blocks = wantsText ? pdf.textBlocks(maximumPages: Self.maximumPages) : []
        return content(
            blocks: blocks, kinds: kinds,
            images: kinds.contains(.pageImages)
                ? pdf.pageImages(
                    maximumPages: Self.maximumPageImages, dimension: Self.maximumImageDimension)
                : nil)
    }

    private func imageContent(of url: URL, kinds: Set<ModuleContentKind>) -> ModuleContent {
        guard let image = ImageRendering.image(at: url, dimension: Self.maximumImageDimension)
        else { return ModuleContent() }
        let wantsText = !kinds.isDisjoint(with: [.text, .positionedText])
        let blocks = wantsText ? TextRecognition.blocks(in: image, page: 0) : []
        let png = kinds.contains(.pageImages) ? ImageRendering.png(of: image) : nil
        return content(blocks: blocks, kinds: kinds, images: png.map { [$0] })
    }

    private func content(
        blocks: [PositionedText], kinds: Set<ModuleContentKind>, images: [Data]?
    ) -> ModuleContent {
        let limited = limit(blocks)
        return ModuleContent(
            text: kinds.contains(.text) && !limited.isEmpty
                ? limited.map(\.text).joined(separator: "\n") : nil,
            positionedText: kinds.contains(.positionedText) && !limited.isEmpty ? limited : nil,
            pageImages: images)
    }

    /// Keeps the blocks that fit within the text limit, counting the line breaks
    /// they are joined with.
    private func limit(_ blocks: [PositionedText]) -> [PositionedText] {
        var remaining = Self.maximumTextLength
        var result: [PositionedText] = []
        for block in blocks {
            remaining -= block.text.count + 1
            guard remaining >= 0 else { break }
            result.append(block)
        }
        return result
    }
}
