import CoreGraphics
import Foundation
import TreewiseModuleInterface
import Vision
import os

/// Recognizes text in an image on the device, with Vision.
enum TextRecognition {
    /// The languages recognized, the app's own three (ADR 0017).
    private static let languages = ["en-US", "nl-NL", "de-DE"]
    private static let logger = Logger(
        subsystem: "me.m-domain.treewise", category: "TextRecognition")

    /// The lines found in an image, positioned from its top left; empty when
    /// recognition fails.
    static func blocks(in image: CGImage, page: Int) -> [PositionedText] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        do {
            try VNImageRequestHandler(cgImage: image).perform([request])
        } catch {
            logger.error("Text recognition failed: \(error.localizedDescription)")
            return []
        }
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            // Vision measures from the bottom left, the interface from the top left.
            return PositionedText(
                text: text, page: page, x: box.minX, y: 1 - box.maxY, width: box.width,
                height: box.height)
        }
    }
}
