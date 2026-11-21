#if DEBUG
    import UIKit

    /// The folders of the App Store's screenshots (ADR 0118), in Debug builds only: made-up
    /// files in English, Dutch or German, as the run's first preferred language says, with
    /// dates before the run and sizes as such files have; a sparse file has its size and no
    /// content.
    enum DemoTree {
        /// A name in each language of the listing.
        struct Name {
            let en: String
            let nl: String
            let de: String

            func text(in language: String) -> String {
                switch language {
                case "nl": nl
                case "de": de
                default: en
                }
            }
        }

        struct Entry {
            let path: [Name]
            let isFolder: Bool
            /// How long before the run the entry was last changed.
            let age: TimeInterval
            let bytes: Int
            /// When a photo was taken, as the camera writes it in the photo.
            var captured: String?

            static func folder(_ path: Name..., age: TimeInterval) -> Entry {
                Entry(path: path, isFolder: true, age: age, bytes: 0)
            }

            static func file(_ path: Name..., age: TimeInterval, bytes: Int) -> Entry {
                Entry(path: path, isFolder: false, age: age, bytes: bytes)
            }
        }

        private static let hour: TimeInterval = 3600
        private static let day: TimeInterval = 24 * hour
        private static let kilobyte = 1000
        private static let megabyte = 1000 * kilobyte
        /// The size of the picture drawn for a photo, in points at a scale of 1.
        private static let photoSize = CGSize(width: 2400, height: 1600)
        private static let photoQuality: CGFloat = 0.85

        static let documents = Name(en: "Documents", nl: "Documenten", de: "Dokumente")
        static let photos = Name(en: "Photos", nl: "Foto’s", de: "Fotos")
        static let work = Name(en: "Work", nl: "Werk", de: "Arbeit")
        static let archive = Name(en: "Archive", nl: "Archief", de: "Archiv")
        static let budget = Name(
            en: "Budget 2026.xlsx", nl: "Begroting 2026.xlsx", de: "Budget 2026.xlsx")
        static let lighthouse = Name(
            en: "Lighthouse.jpg", nl: "Vuurtoren.jpg", de: "Leuchtturm.jpg")

        /// The added folders, in the order of the sidebar's.
        static let tops = [documents, photos, work]

        static let entries: [Entry] =
            [
                .folder(documents, archive, age: 9 * day),
                .file(documents, archive, budget, age: 40 * day, bytes: 41 * kilobyte),
                .file(
                    documents, archive,
                    Name(
                        en: "Tax return 2025.pdf", nl: "Belastingaangifte 2025.pdf",
                        de: "Steuererklärung 2025.pdf"),
                    age: 60 * day, bytes: 820 * kilobyte),
                .folder(
                    documents, Name(en: "Invoices", nl: "Facturen", de: "Rechnungen"), age: 3 * day),
                .folder(
                    documents, Name(en: "Recipes", nl: "Recepten", de: "Rezepte"), age: 21 * day),
                .folder(
                    documents, Name(en: "Travel", nl: "Reizen", de: "Reisen"),
                    age: 1 * day + 5 * hour),
                .file(documents, budget, age: 2 * hour, bytes: 48 * kilobyte),
                .file(
                    documents,
                    Name(
                        en: "Meeting notes.docx", nl: "Notulen overleg.docx",
                        de: "Besprechungsnotizen.docx"),
                    age: 26 * hour, bytes: 112 * kilobyte),
                .file(
                    documents,
                    Name(en: "Garden plan.pdf", nl: "Tuinplan.pdf", de: "Gartenplan.pdf"),
                    age: 5 * day, bytes: 2_300 * kilobyte),
                .file(documents, lighthouse, age: 6 * day, bytes: 0),
                .file(
                    documents,
                    Name(en: "Moving checklist.txt", nl: "Verhuislijst.txt", de: "Umzugsliste.txt"),
                    age: 12 * day, bytes: 3 * kilobyte),
                .file(
                    documents,
                    Name(en: "Presentation.key", nl: "Presentatie.key", de: "Präsentation.key"),
                    age: 33 * day, bytes: 14 * megabyte),
                .file(
                    documents, Name(en: "Reading list.md", nl: "Leeslijst.md", de: "Leseliste.md"),
                    age: 45 * day, bytes: 2 * kilobyte),
                .file(
                    documents,
                    Name(en: "Birthdays.txt", nl: "Verjaardagen.txt", de: "Geburtstage.txt"),
                    age: 90 * day, bytes: 1 * kilobyte),
                .file(
                    documents,
                    Name(
                        en: "Car insurance.pdf", nl: "Autoverzekering.pdf",
                        de: "Autoversicherung.pdf"),
                    age: 120 * day, bytes: 310 * kilobyte),
                .file(
                    documents,
                    Name(en: "Floor plan.pdf", nl: "Plattegrond.pdf", de: "Grundriss.pdf"),
                    age: 17 * day, bytes: 1_200 * kilobyte),
                .file(
                    documents,
                    Name(
                        en: "Holiday budget.xlsx", nl: "Vakantiebudget.xlsx",
                        de: "Urlaubsbudget.xlsx"),
                    age: 3 * hour, bytes: 26 * kilobyte),
                .file(
                    documents,
                    Name(
                        en: "Letter to the landlord.docx", nl: "Brief aan de verhuurder.docx",
                        de: "Brief an den Vermieter.docx"),
                    age: 2 * day, bytes: 38 * kilobyte),
                .file(
                    documents, Name(en: "Packing list.md", nl: "Paklijst.md", de: "Packliste.md"),
                    age: 4 * day, bytes: 1 * kilobyte),
                .file(
                    documents,
                    Name(
                        en: "Wedding speech.docx", nl: "Speech bruiloft.docx",
                        de: "Hochzeitsrede.docx"),
                    age: 50 * day, bytes: 64 * kilobyte),
                .folder(photos, summer, age: 70 * day),
                .file(
                    photos, Name(en: "Beach.jpg", nl: "Strand.jpg", de: "Strand.jpg"),
                    age: 72 * day,
                    bytes: 0),
                .file(
                    photos, Name(en: "Dunes.jpg", nl: "Duinen.jpg", de: "Dünen.jpg"), age: 72 * day,
                    bytes: 0),
                .file(
                    work,
                    Name(
                        en: "Quarterly report.pdf", nl: "Kwartaalrapport.pdf",
                        de: "Quartalsbericht.pdf"
                    ), age: 4 * day, bytes: 1_600 * kilobyte),
                .file(
                    work,
                    Name(en: "Roadmap.numbers", nl: "Planning.numbers", de: "Planung.numbers"),
                    age: 8 * day, bytes: 380 * kilobyte),
            ] + summerPhotos

        /// Makes the tree in `folder` unless it is there, and returns its added folders.
        static func make(in folder: URL) throws -> [URL] {
            let language = language
            let manager = FileManager.default
            let now = Date.now
            let tops = tops.map { folder.appendingPathComponent($0.text(in: language)) }
            if tops.allSatisfy({ manager.fileExists(atPath: $0.path) }) { return tops }
            for top in tops {
                try manager.createDirectory(at: top, withIntermediateDirectories: true)
            }
            for entry in entries {
                let url = entry.path.reduce(folder) {
                    $0.appendingPathComponent($1.text(in: language))
                }
                if entry.isFolder {
                    try manager.createDirectory(at: url, withIntermediateDirectories: true)
                } else {
                    try write(entry, to: url)
                }
            }
            // A file written into a folder changes the folder's date, so dates come last,
            // the deepest first.
            for entry in entries.sorted(by: { $0.path.count > $1.path.count }) {
                let url = entry.path.reduce(folder) {
                    $0.appendingPathComponent($1.text(in: language))
                }
                try manager.setAttributes(
                    [.modificationDate: now - entry.age], ofItemAtPath: url.path)
            }
            return tops
        }

        private static func write(_ entry: Entry, to url: URL) throws {
            if url.pathExtension == "jpg" {
                let picture = photo(named: url.lastPathComponent)
                try (entry.captured.flatMap { taken(picture, at: $0) } ?? picture).write(to: url)
            } else if ["txt", "md"].contains(url.pathExtension) {
                let line = "\(url.deletingPathExtension().lastPathComponent)\n"
                let lines = max(1, entry.bytes / line.utf8.count)
                try Data(String(repeating: line, count: lines).utf8).write(to: url)
            } else {
                FileManager.default.createFile(atPath: url.path, contents: nil)
                let handle = try FileHandle(forWritingTo: url)
                try handle.truncate(atOffset: UInt64(entry.bytes))
                try handle.close()
            }
        }

        /// A sunset over the sea with a lighthouse on the beach, the sky's colours chosen from
        /// the name, so each photo differs and is the same every run.
        private static func photo(named name: String) -> Data {
            let seed = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
            let skies: [(UIColor, UIColor)] = [
                (
                    UIColor(red: 0.98, green: 0.72, blue: 0.47, alpha: 1),
                    UIColor(red: 0.35, green: 0.47, blue: 0.78, alpha: 1)
                ),
                (
                    UIColor(red: 0.99, green: 0.62, blue: 0.62, alpha: 1),
                    UIColor(red: 0.29, green: 0.24, blue: 0.55, alpha: 1)
                ),
                (
                    UIColor(red: 0.6, green: 0.8, blue: 0.98, alpha: 1),
                    UIColor(red: 0.16, green: 0.43, blue: 0.78, alpha: 1)
                ),
            ]
            let sky = skies[seed % skies.count]
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: photoSize, format: format).image { context in
                let cg = context.cgContext
                gradient(sky.1, sky.0, in: CGRect(x: 0, y: 0, width: 1, height: 0.62), on: cg)
                UIColor(red: 1, green: 0.93, blue: 0.75, alpha: 1).setFill()
                cg.fillEllipse(in: scaled(CGRect(x: 0.66, y: 0.42, width: 0.12, height: 0.18)))
                gradient(
                    UIColor(red: 0.2, green: 0.38, blue: 0.55, alpha: 1),
                    UIColor(red: 0.1, green: 0.22, blue: 0.36, alpha: 1),
                    in: CGRect(x: 0, y: 0.62, width: 1, height: 0.22), on: cg)
                UIColor(red: 0.86, green: 0.76, blue: 0.58, alpha: 1).setFill()
                cg.fill(scaled(CGRect(x: 0, y: 0.84, width: 1, height: 0.16)))
                lighthouse(on: cg)
            }
            return image.jpegData(compressionQuality: photoQuality) ?? Data()
        }

        /// A white tower with red bands and a dark lantern, on the beach at the left.
        private static func lighthouse(on cg: CGContext) {
            UIColor.white.setFill()
            cg.fill(scaled(CGRect(x: 0.2, y: 0.3, width: 0.05, height: 0.58)))
            UIColor(red: 0.8, green: 0.16, blue: 0.16, alpha: 1).setFill()
            for band in 0..<3 {
                cg.fill(
                    scaled(
                        CGRect(x: 0.2, y: 0.38 + CGFloat(band) * 0.16, width: 0.05, height: 0.07)))
            }
            UIColor(white: 0.15, alpha: 1).setFill()
            cg.fill(scaled(CGRect(x: 0.19, y: 0.25, width: 0.07, height: 0.05)))
            UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1).setFill()
            cg.fill(scaled(CGRect(x: 0.205, y: 0.26, width: 0.04, height: 0.03)))
        }

        /// A rectangle given in parts of the picture's width and height, in points.
        private static func scaled(_ rect: CGRect) -> CGRect {
            CGRect(
                x: rect.minX * photoSize.width, y: rect.minY * photoSize.height,
                width: rect.width * photoSize.width, height: rect.height * photoSize.height)
        }

        private static func gradient(
            _ top: UIColor, _ bottom: UIColor, in rect: CGRect, on cg: CGContext
        ) {
            let area = scaled(rect)
            guard
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [top.cgColor, bottom.cgColor] as CFArray,
                    locations: [0, 1])
            else { return }
            cg.saveGState()
            cg.clip(to: area)
            cg.drawLinearGradient(
                gradient, start: CGPoint(x: 0, y: area.minY), end: CGPoint(x: 0, y: area.maxY),
                options: [])
            cg.restoreGState()
        }
    }
#endif
