// Renders the disk image background SVG to a PNG at a given scale with AppKit,
// which reads SVG, so no extra tool is needed (tools/build.sh package, ADR 0034).
//
//   swift tools/dmg/render.swift <background.svg> <output.png> <scale>

import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("render.swift: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count == 4, let scale = Int(arguments[3]), scale > 0 else {
    fail("usage: render.swift <background.svg> <output.png> <scale>")
}
guard let image = NSImage(contentsOfFile: arguments[1]) else { fail("cannot read \(arguments[1])") }
let width = Int(image.size.width) * scale
let height = Int(image.size.height) * scale
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)
else { fail("no bitmap") }
// The point size stays the SVG's, so the 2x image carries Retina resolution.
bitmap.size = image.size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
image.draw(in: NSRect(origin: .zero, size: image.size))
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { fail("no PNG") }
do {
    try png.write(to: URL(fileURLWithPath: arguments[2]))
} catch {
    fail("cannot write \(arguments[2]): \(error.localizedDescription)")
}
