import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Makes pictures within a size limit, without a UI framework, so it works alike
/// on the Mac and the iPad.
enum ImageRendering {
    private static let bitsPerComponent = 8

    /// Reads an image file, scaled down so its longest side fits `dimension`.
    static func image(at url: URL, dimension: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: dimension,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Draws a PDF page on white, scaled so its longest side is `dimension`.
    static func image(of page: CGPDFPage, dimension: Int) -> CGImage? {
        let box = page.getBoxRect(.mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = CGFloat(dimension) / max(box.width, box.height)
        let size = CGSize(
            width: (box.width * scale).rounded(), height: (box.height * scale).rounded())
        guard
            let context = CGContext(
                data: nil, width: Int(size.width), height: Int(size.height),
                bitsPerComponent: bitsPerComponent, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }

    /// Encodes an image as PNG.
    static func png(of image: CGImage) -> Data? {
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
