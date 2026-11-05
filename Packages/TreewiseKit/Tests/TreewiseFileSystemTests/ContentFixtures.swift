import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Writes small documents for the extraction tests, inside a `TempDirectory`.
enum ContentFixtures {
    static let pageSize = CGSize(width: 600, height: 800)
    private static let fontSize: CGFloat = 36
    private static let lineHeight: CGFloat = 60

    /// A PDF with real text: one array of lines per page, the first line on top.
    static func writePDF(pages: [[String]], to url: URL) throws {
        var box = CGRect(origin: .zero, size: pageSize)
        let context = try require(url, CGContext(url as CFURL, mediaBox: &box, nil))
        for lines in pages {
            context.beginPDFPage(nil)
            draw(lines, in: context, height: pageSize.height)
            context.endPDFPage()
        }
        context.closePDF()
    }

    /// A PDF that holds only an image of its text, as a scan does.
    static func writeScannedPDF(lines: [String], to url: URL) throws {
        var box = CGRect(origin: .zero, size: pageSize)
        let context = try require(url, CGContext(url as CFURL, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.draw(try image(lines: lines), in: box)
        context.endPDFPage()
        context.closePDF()
    }

    /// A PNG picture of text.
    static func writePNG(lines: [String], to url: URL) throws {
        let destination = try require(
            url,
            CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, try image(lines: lines), nil)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError.notCreated(url) }
    }

    private static func image(lines: [String]) throws -> CGImage {
        let context = try require(
            nil,
            CGContext(
                data: nil, width: Int(pageSize.width), height: Int(pageSize.height),
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: pageSize))
        draw(lines, in: context, height: pageSize.height)
        return try require(nil, context.makeImage())
    }

    private static func draw(_ lines: [String], in context: CGContext, height: CGFloat) {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        for (index, line) in lines.enumerated() {
            let attributed = NSAttributedString(
                string: line,
                attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String):
                        CGColor(gray: 0, alpha: 1),
                ])
            context.textPosition = CGPoint(x: 40, y: height - lineHeight * CGFloat(index + 1))
            CTLineDraw(CTLineCreateWithAttributedString(attributed), context)
        }
    }

    private static func require<T>(_ url: URL?, _ value: T?) throws -> T {
        guard let value else { throw FixtureError.notCreated(url) }
        return value
    }
}

enum FixtureError: Error {
    case notCreated(URL?)
}
