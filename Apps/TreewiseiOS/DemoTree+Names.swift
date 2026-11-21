#if DEBUG
    import Foundation
    import ImageIO
    import UniformTypeIdentifiers

    /// What the App Store's screens of names and templates show on the demo tree (ADR 0145):
    /// photos with the date they were taken, so Rename with Suggestions names the camera's
    /// photo after the others, and a template in each language for New Folders from Template.
    extension DemoTree.Entry {
        /// A photo taken at `captured`, `yyyy:MM:dd HH:mm:ss` as in EXIF data.
        static func photo(
            _ path: DemoTree.Name..., age: TimeInterval, captured: String
        ) -> DemoTree.Entry {
            DemoTree.Entry(path: path, isFolder: false, age: age, bytes: 0, captured: captured)
        }
    }

    extension DemoTree {
        static let summer = Name(en: "Summer 2026", nl: "Zomer 2026", de: "Sommer 2026")
        /// The photo named by the camera, which Rename with Suggestions names after the others.
        static let cameraPhoto = Name(en: "IMG_4127.jpg", nl: "IMG_4127.jpg", de: "IMG_4127.jpg")
        private static let oneDay: TimeInterval = 24 * 3600

        /// The language the names are in: the run's first preferred one of en, nl and de.
        static var language: String {
            let first = Locale.preferredLanguages.first.map { Locale(identifier: $0) }
            return first?.language.languageCode?.identifier ?? "en"
        }

        /// The folders Favorites shows, in `folder`'s tree: none the walk finds by name, as
        /// a favorite's row has its folder's name.
        static func favorites(in folder: URL) -> [URL] {
            let language = language
            return [invoices, travel, recipes].map {
                folder.appendingPathComponent(documents.text(in: language))
                    .appendingPathComponent($0.text(in: language))
            }
        }

        /// Three photos named by the day they were taken and the place, the least a pattern
        /// is recognized from, and the camera's, in the summer's folder: the place is the
        /// same in each, so the suggestion is a whole name.
        static let summerPhotos: [Entry] = [
            .photo(
                photos, summer,
                Name(
                    en: "2026-07-12 Cornwall.jpg", nl: "2026-07-12 Texel.jpg",
                    de: "2026-07-12 Sylt.jpg"),
                age: 131 * oneDay, captured: "2026:07:12 10:42:00"),
            .photo(
                photos, summer,
                Name(
                    en: "2026-07-13 Cornwall.jpg", nl: "2026-07-13 Texel.jpg",
                    de: "2026-07-13 Sylt.jpg"),
                age: 130 * oneDay, captured: "2026:07:13 17:05:00"),
            .photo(
                photos, summer,
                Name(
                    en: "2026-07-14 Cornwall.jpg", nl: "2026-07-14 Texel.jpg",
                    de: "2026-07-14 Sylt.jpg"),
                age: 129 * oneDay, captured: "2026:07:14 09:18:00"),
            .photo(photos, summer, cameraPhoto, age: 128 * oneDay, captured: "2026:07:15 19:36:00"),
        ]

        /// The template's name in each language.
        static let templateName = Name(
            en: "Household Year", nl: "Huishoudjaar", de: "Haushaltsjahr")
        private static let templateFolders = [
            Name(en: "Tax", nl: "Belasting", de: "Steuern"),
            Name(en: "Insurance", nl: "Verzekeringen", de: "Versicherungen"),
            Name(en: "Receipts", nl: "Bonnetjes", de: "Belege"),
        ]

        /// `jpeg` with `captured` as the date it was taken in its EXIF data; nil when it
        /// cannot be written.
        static func taken(_ jpeg: Data, at captured: String) -> Data? {
            guard let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else {
                return nil
            }
            let data = NSMutableData()
            guard
                let destination = CGImageDestinationCreateWithData(
                    data, UTType.jpeg.identifier as CFString, 1, nil)
            else { return nil }
            let exif: [CFString: Any] = [kCGImagePropertyExifDateTimeOriginal: captured]
            CGImageDestinationAddImageFromSource(
                destination, source, 0, [kCGImagePropertyExifDictionary: exif] as CFDictionary)
            return CGImageDestinationFinalize(destination) ? data as Data : nil
        }

        /// Keeps the template in `folder`, the run's templates, unless it is there.
        static func seedTemplate(in folder: URL) throws {
            let file = folder.appendingPathComponent("household-year.json")
            guard !FileManager.default.fileExists(atPath: file.path) else { return }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let language = language
            let template: [String: Any] = [
                "format": 1, "id": "household-year", "name": templateName.text(in: language),
                "root": [
                    "name": "{year}",
                    "folders": templateFolders.map { ["name": $0.text(in: language)] },
                ],
            ]
            try JSONSerialization.data(withJSONObject: template, options: [.sortedKeys])
                .write(to: file)
        }
    }
#endif
