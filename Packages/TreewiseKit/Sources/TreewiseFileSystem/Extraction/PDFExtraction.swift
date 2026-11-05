import CoreGraphics
import Foundation
import PDFKit
import TreewiseModuleInterface

/// The text and page images of one PDF. A page without text counts as a scan, and
/// its text is recognized from a picture of the page.
struct PDFExtraction {
    private let document: PDFDocument
    private let rendering: CGPDFDocument

    /// Opens a PDF; nil when it is damaged or locked with a password.
    init?(url: URL) {
        guard let document = PDFDocument(url: url), !document.isLocked,
            let rendering = CGPDFDocument(url as CFURL)
        else { return nil }
        self.document = document
        self.rendering = rendering
    }

    /// The lines of the first pages, positioned from the top left of their page.
    func textBlocks(maximumPages: Int) -> [PositionedText] {
        (0..<min(document.pageCount, maximumPages)).flatMap { index in
            guard let page = document.page(at: index) else { return [PositionedText]() }
            let lines = lines(of: page, index: index)
            return lines.isEmpty ? recognizedLines(ofPage: index) : lines
        }
    }

    /// PNG pictures of the first pages.
    func pageImages(maximumPages: Int, dimension: Int) -> [Data] {
        (0..<min(document.pageCount, maximumPages)).compactMap { index in
            picture(ofPage: index, dimension: dimension).flatMap(ImageRendering.png)
        }
    }

    private func lines(of page: PDFPage, index: Int) -> [PositionedText] {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0,
            let selections = page.selection(for: bounds)?.selectionsByLine()
        else { return [] }
        return selections.compactMap { line in
            guard let text = line.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty
            else { return nil }
            let box = line.bounds(for: page)
            // PDF measures from the bottom left, the interface from the top left.
            return PositionedText(
                text: text, page: index, x: (box.minX - bounds.minX) / bounds.width,
                y: (bounds.maxY - box.maxY) / bounds.height, width: box.width / bounds.width,
                height: box.height / bounds.height)
        }
    }

    private func recognizedLines(ofPage index: Int) -> [PositionedText] {
        guard let image = picture(ofPage: index, dimension: ContentExtractor.maximumImageDimension)
        else { return [] }
        return TextRecognition.blocks(in: image, page: index)
    }

    private func picture(ofPage index: Int, dimension: Int) -> CGImage? {
        // CGPDFDocument numbers its pages from 1.
        rendering.page(at: index + 1).flatMap { ImageRendering.image(of: $0, dimension: dimension) }
    }
}
