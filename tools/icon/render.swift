// Renders the app icon SVG to a square PNG with AppKit, which reads SVG, so
// no extra tool is needed (tools/build.sh icon).
//
//   swift tools/icon/render.swift <icon.svg> <output.png> <pixels> [--full-bleed]
//
// --full-bleed replaces the rounded plate (the SVG's `<g id="plate">`) with
// one that fills the square, crops to it and writes no alpha channel, as iOS
// wants: the system rounds the corners itself.

import AppKit
import UniformTypeIdentifiers

/// The plate's place on the 1024-point macOS icon grid.
let canvas: CGFloat = 1024
let plateInset: CGFloat = 100

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("render.swift: \(message)\n".utf8))
    exit(1)
}

/// The SVG with its plate group swapped for a plate that covers the canvas.
func fullBleed(_ svg: String) -> String {
    guard let start = svg.range(of: "<g id=\"plate\">"),
        let end = svg.range(of: "</g>", range: start.upperBound..<svg.endIndex)
    else { fail("no <g id=\"plate\"> in the SVG") }
    let plate = "<rect x=\"0\" y=\"0\" width=\"1024\" height=\"1024\" fill=\"url(#plate)\"/>"
    return svg.replacingCharacters(in: start.lowerBound..<end.upperBound, with: plate)
}

/// Draws `image` into a square of `pixels`, cropped to the plate when `crop`.
func render(_ image: NSImage, pixels: Int, crop: Bool) -> CGImage {
    let size = CGFloat(pixels)
    let info = crop ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
    guard
        let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info.rawValue)
    else { fail("no bitmap context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    if crop {
        let scale = size / (canvas - 2 * plateInset)
        image.draw(
            in: NSRect(
                x: -plateInset * scale, y: -plateInset * scale, width: canvas * scale,
                height: canvas * scale))
    } else {
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let result = context.makeImage() else { fail("no image") }
    return result
}

let arguments = CommandLine.arguments
guard arguments.count >= 4, let pixels = Int(arguments[3]) else {
    fail("usage: render.swift <icon.svg> <output.png> <pixels> [--full-bleed]")
}
let crop = arguments.dropFirst(4).contains("--full-bleed")
guard var svg = try? String(contentsOfFile: arguments[1], encoding: .utf8) else {
    fail("cannot read \(arguments[1])")
}
if crop { svg = fullBleed(svg) }
guard let image = NSImage(data: Data(svg.utf8)) else { fail("cannot read the SVG") }

let output = URL(fileURLWithPath: arguments[2])
guard
    let destination = CGImageDestinationCreateWithURL(
        output as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("cannot write \(output.path)") }
CGImageDestinationAddImage(destination, render(image, pixels: pixels, crop: crop), nil)
guard CGImageDestinationFinalize(destination) else { fail("cannot write \(output.path)") }
