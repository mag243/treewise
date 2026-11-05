import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import TreewiseCore
import UniformTypeIdentifiers

/// Reads the date a file suggests for its name (ADR 0057): first one inside the file,
/// which often stays right when a file reaches the disk later, then the oldest the file
/// system knows. It reads only that date, so contents stay out of it.
public struct FileDateReader: Sendable {
    /// The separators in EXIF's `2024:05:06 22:30:00`.
    private static let exifSeparators = CharacterSet(charactersIn: ": ")
    private static let exifDateParts = 3

    private let calendar: Calendar

    /// Creates a reader. The calendar's time zone decides which day a moment falls on.
    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// The date of the file at `url`, or nil when it has none. A file that is only online
    /// is not opened, because that would start downloading it.
    public func suggestedDate(of url: URL, isOnlyOnline: Bool) -> SuggestedDate? {
        let values = try? url.resourceValues(forKeys: [
            .contentTypeKey, .creationDateKey, .contentModificationDateKey,
        ])
        if !isOnlyOnline, let type = values?.contentType,
            let inside = date(inside: url, type: type)
        {
            return inside
        }
        let dates = [values?.creationDate, values?.contentModificationDate].compactMap(\.self)
        return dates.min().map { suggested($0, source: .fileSystem) }
    }

    private func date(inside url: URL, type: UTType) -> SuggestedDate? {
        if type.conforms(to: .pdf) {
            let attributes = PDFDocument(url: url)?.documentAttributes
            return (attributes?[PDFDocumentAttribute.creationDateAttribute] as? Date)
                .map { suggested($0, source: .insideFile) }
        }
        return type.conforms(to: .image) ? captureDate(of: url) : nil
    }

    /// A photo's capture date is written as local time, without a zone, so it is taken as it is.
    private func captureDate(of url: URL) -> SuggestedDate? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
            let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String
        else { return nil }
        let parts = text.components(separatedBy: Self.exifSeparators).prefix(Self.exifDateParts)
            .compactMap { Int($0) }
        guard parts.count == Self.exifDateParts else { return nil }
        return SuggestedDate(year: parts[0], month: parts[1], day: parts[2], source: .insideFile)
    }

    private func suggested(_ date: Date, source: NameProposal.DateSource) -> SuggestedDate {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return SuggestedDate(
            year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0, source: source)
    }
}
