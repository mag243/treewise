import CoreGraphics
import Foundation
import ImageIO
import Testing
import TreewiseFileSystem
import TreewiseModuleInterface
import TreewiseTestSupport

/// What Treewise hands a module from a chosen file (ADR 0057).
@Suite struct ContentExtractorTests {
    private let folder: TempDirectory
    private let extractor = ContentExtractor()

    init() throws {
        folder = try TempDirectory()
    }

    private func pdf(_ pages: [[String]]) throws -> URL {
        let url = folder.url("doc.pdf")
        try ContentFixtures.writePDF(pages: pages, to: url)
        return url
    }

    @Test func givesNothingWhenNothingIsDeclared() throws {
        let content = extractor.content(of: try pdf([["Invoice"]]), kinds: [])
        #expect(content == ModuleContent())
    }

    @Test func givesOnlyWhatIsDeclared() throws {
        let content = extractor.content(of: try pdf([["Invoice"]]), kinds: [.text])
        #expect(content.text?.contains("Invoice") == true)
        #expect(content.positionedText == nil)
        #expect(content.pageImages == nil)
    }

    @Test func readsAPlainTextFile() throws {
        let url = folder.url("notes.txt")
        try Data("Dear customer".utf8).write(to: url)
        #expect(extractor.content(of: url, kinds: [.text]).text == "Dear customer")
    }

    @Test func limitsAPlainTextFile() throws {
        let url = folder.url("long.txt")
        let long = String(repeating: "a", count: ContentExtractor.maximumTextLength + 10)
        try Data(long.utf8).write(to: url)
        #expect(
            extractor.content(of: url, kinds: [.text]).text?.count
                == ContentExtractor.maximumTextLength)
    }

    @Test func survivesInvalidUTF8() throws {
        let url = folder.url("broken.txt")
        try Data([0x41, 0xFF, 0x42]).write(to: url)
        #expect(extractor.content(of: url, kinds: [.text]).text?.hasPrefix("A") == true)
    }

    @Test func readsTextFromEveryPageOfAPDF() throws {
        let text = extractor.content(of: try pdf([["First"], ["Second"]]), kinds: [.text]).text
        #expect(text?.contains("First") == true)
        #expect(text?.contains("Second") == true)
    }

    @Test func limitsThePagesItReads() throws {
        let pages = (0...ContentExtractor.maximumPages).map { ["Page\($0)x"] }
        let text = extractor.content(of: try pdf(pages), kinds: [.text]).text
        #expect(text?.contains("Page0x") == true)
        #expect(text?.contains("Page\(ContentExtractor.maximumPages)x") == false)
    }

    @Test func givesPositionsMeasuredFromTheTopOfThePage() throws {
        let blocks = try #require(
            extractor.content(of: try pdf([["Top", "Below"]]), kinds: [.positionedText])
                .positionedText)
        let top = try #require(blocks.first { $0.text.contains("Top") })
        let below = try #require(blocks.first { $0.text.contains("Below") })
        #expect(top.page == 0)
        #expect(top.y < below.y)
        #expect((0...1).contains(top.x))
        #expect(top.width > 0 && top.height > 0)
    }

    @Test func numbersThePagesOfPositionedText() throws {
        let blocks = extractor.content(of: try pdf([["One"], ["Two"]]), kinds: [.positionedText])
            .positionedText
        #expect(blocks?.first { $0.text.contains("Two") }?.page == 1)
    }

    @Test func rendersPagesAsPNG() throws {
        let images = extractor.content(of: try pdf([["One"], ["Two"]]), kinds: [.pageImages])
            .pageImages
        #expect(images?.count == 2)
        #expect(images?.first.map(isPNG) == true)
    }

    @Test func limitsTheSizeOfARenderedPage() throws {
        let image = try #require(
            extractor.content(of: try pdf([["One"]]), kinds: [.pageImages]).pageImages?.first)
        let source = try #require(CGImageSourceCreateWithData(image as CFData, nil))
        let picture = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(max(picture.width, picture.height) <= ContentExtractor.maximumImageDimension)
    }

    @Test func limitsTheImagesItRenders() throws {
        let pages = (0...ContentExtractor.maximumPageImages).map { ["\($0)"] }
        let images = extractor.content(of: try pdf(pages), kinds: [.pageImages]).pageImages
        #expect(images?.count == ContentExtractor.maximumPageImages)
    }

    @Test func givesAPictureOfAnImage() throws {
        let url = folder.url("photo.png")
        try ContentFixtures.writePNG(lines: ["Hello"], to: url)
        #expect(extractor.content(of: url, kinds: [.pageImages]).pageImages?.count == 1)
    }

    @Test func givesNothingFromADamagedPDF() throws {
        let url = folder.url("damaged.pdf")
        try Data("not a pdf".utf8).write(to: url)
        let all = Set(ModuleContentKind.allCases)
        #expect(extractor.content(of: url, kinds: all) == ModuleContent())
    }

    @Test func givesNothingFromAMissingFile() {
        let all = Set(ModuleContentKind.allCases)
        #expect(extractor.content(of: folder.url("gone.pdf"), kinds: all) == ModuleContent())
    }

    @Test func givesNothingFromAFormatItDoesNotRead() throws {
        let url = folder.url("data.zip")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: url)
        let all = Set(ModuleContentKind.allCases)
        #expect(extractor.content(of: url, kinds: all) == ModuleContent())
    }

    private func isPNG(_ data: Data) -> Bool {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47])
    }

    // Text recognition needs Vision's models, which the iOS Simulator may lack.
    #if os(macOS)
        @Test func recognizesTheTextOfAScan() throws {
            let url = folder.url("scan.pdf")
            try ContentFixtures.writeScannedPDF(lines: ["Invoice 4711"], to: url)
            #expect(extractor.content(of: url, kinds: [.text]).text?.contains("4711") == true)
        }

        @Test func positionsTheRecognizedTextOfAScanFromTheTop() throws {
            let url = folder.url("scan.pdf")
            try ContentFixtures.writeScannedPDF(
                lines: ["Invoice 4711", "", "", "Total 99"], to: url)
            let blocks = try #require(
                extractor.content(of: url, kinds: [.positionedText]).positionedText)
            let top = try #require(blocks.first { $0.text.contains("4711") })
            let below = try #require(blocks.first { $0.text.contains("99") })
            #expect(top.y < below.y)
        }

        @Test func recognizesTheTextOfAnImage() throws {
            let url = folder.url("photo.png")
            try ContentFixtures.writePNG(lines: ["Invoice 4711"], to: url)
            #expect(extractor.content(of: url, kinds: [.text]).text?.contains("4711") == true)
        }
    #endif
}
