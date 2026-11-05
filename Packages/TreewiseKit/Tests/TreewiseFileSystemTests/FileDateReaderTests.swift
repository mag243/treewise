import CoreGraphics
import Foundation
import ImageIO
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport
import UniformTypeIdentifiers

/// Which date a file suggests, and where it comes from (ADR 0057).
@Suite struct FileDateReaderTests {
    private let folder: TempDirectory
    private let reader = FileDateReader(calendar: Calendar(identifier: .gregorian))
    private let old = Date(timeIntervalSince1970: 1_577_836_800)  // 1 January 2020 UTC
    private let older = Date(timeIntervalSince1970: 1_546_300_800)  // 1 January 2019 UTC

    init() throws {
        folder = try TempDirectory()
    }

    private func setDates(of url: URL, created: Date, modified: Date) throws {
        try FileManager.default.setAttributes(
            [.creationDate: created, .modificationDate: modified], ofItemAtPath: url.path)
    }

    private func year(_ date: SuggestedDate?) -> Int? { date?.year }

    @Test func aPDFsOwnDateWinsOverTheFiles() throws {
        let url = folder.url("doc.pdf")
        try ContentFixtures.writePDF(pages: [["One"]], to: url)
        try setDates(of: url, created: old, modified: old)
        let date = reader.suggestedDate(of: url, isOnlyOnline: false)
        #expect(date?.source == .insideFile)
        #expect((date?.year ?? 0) > 2020)
    }

    @Test func aPhotosCaptureDateWinsOverTheFiles() throws {
        let url = folder.url("photo.jpg")
        try Self.writeJPEG(captured: "2024:05:06 22:30:00", to: url)
        try setDates(of: url, created: old, modified: old)
        let date = reader.suggestedDate(of: url, isOnlyOnline: false)
        #expect(date == SuggestedDate(year: 2024, month: 5, day: 6, source: .insideFile))
    }

    @Test func otherFilesGiveTheOldestDate() throws {
        let url = folder.url("notes.txt")
        try Data("x".utf8).write(to: url)
        try setDates(of: url, created: old, modified: older)
        let date = reader.suggestedDate(of: url, isOnlyOnline: false)
        #expect(date?.source == .fileSystem)
        #expect(year(date) == 2019)
    }

    @Test func aDamagedPDFGivesTheFilesDate() throws {
        let url = folder.url("damaged.pdf")
        try Data("not a pdf".utf8).write(to: url)
        #expect(reader.suggestedDate(of: url, isOnlyOnline: false)?.source == .fileSystem)
    }

    @Test func aFileThatIsOnlyOnlineIsNotOpened() throws {
        let url = folder.url("doc.pdf")
        try ContentFixtures.writePDF(pages: [["One"]], to: url)
        #expect(reader.suggestedDate(of: url, isOnlyOnline: true)?.source == .fileSystem)
    }

    @Test func aMissingFileGivesNoDate() {
        #expect(reader.suggestedDate(of: folder.url("gone.pdf"), isOnlyOnline: false) == nil)
    }

    @Test func usesTheLocalDay() throws {
        var amsterdam = Calendar(identifier: .gregorian)
        amsterdam.timeZone = try #require(TimeZone(identifier: "Europe/Amsterdam"))
        var tokyo = amsterdam
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let url = folder.url("notes.txt")
        try Data("x".utf8).write(to: url)
        // 31 December 2019, 16:00 UTC: still that day in Amsterdam, the next in Tokyo.
        let moment = Date(timeIntervalSince1970: 1_577_808_000)
        try setDates(of: url, created: moment, modified: moment)
        #expect(
            FileDateReader(calendar: amsterdam).suggestedDate(of: url, isOnlyOnline: false)?.day
                == 31)
        #expect(
            FileDateReader(calendar: tokyo).suggestedDate(of: url, isOnlyOnline: false)?.day == 1)
    }

    private static func writeJPEG(captured: String, to url: URL) throws {
        let context = try #require(
            CGContext(
                data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage())
        let destination = try #require(
            CGImageDestinationCreateWithURL(
                url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        let exif: [CFString: Any] = [kCGImagePropertyExifDateTimeOriginal: captured]
        let properties: [CFString: Any] = [kCGImagePropertyExifDictionary: exif]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }
}
