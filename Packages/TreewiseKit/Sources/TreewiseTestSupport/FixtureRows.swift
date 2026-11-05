import TreewiseCore

/// The rows of the standard fixture, in the order of the prototype's `seedFs()`.
enum FixtureRows {
    struct Row {
        var id: String
        var name: String
        var kind: ItemKind = .file
        var parent: String?
        var date: String?
        var size: Int64?
        var kindDescription: String?
    }

    /// Returns the top-level location an item lives in.
    ///
    /// Precondition: `id` is one of the rows.
    static func location(of id: String) -> String {
        var current = id
        while let parent = parentByID[current] ?? nil {
            current = parent
        }
        return current
    }

    private static let parentByID = Dictionary(all.map { ($0.id, $0.parent) }) { first, _ in first }

    private static func location(_ id: String, _ name: String, _ kind: ItemKind) -> Row {
        Row(id: id, name: name, kind: kind, parent: nil, date: nil, size: nil, kindDescription: nil)
    }

    private static func folder(_ id: String, _ name: String, _ parent: String, _ date: String)
        -> Row
    {
        Row(
            id: id, name: name, kind: .folder, parent: parent, date: date, size: nil,
            kindDescription: nil)
    }

    private static func app(_ id: String, _ name: String, _ date: String, _ size: Int64) -> Row {
        Row(
            id: id, name: name, kind: .package, parent: "apps", date: date, size: size,
            kindDescription: "Application")
    }

    static let all: [Row] = locations + system + home + documents + media + projects + external

    private static let locations = [
        location("hd", "Macintosh HD", .volume),
        location("icloud", "iCloud Drive", .cloud),
        location("usb", "SAMSUNG T7", .volume),
    ]

    private static let system = [
        folder("apps", "Applications", "hd", "2026-10-20 09:12"),
        folder("lib", "Library", "hd", "2026-09-30 18:40"),
        folder("sys", "System", "hd", "2026-09-15 10:02"),
        folder("users", "Users", "hd", "2026-06-02 08:15"),
        app("a1", "Safari.app", "2026-10-14 07:30", 14_200_000),
        app("a2", "Xcode.app", "2026-10-02 22:10", 11_800_000_000),
        app("a3", "Mail.app", "2026-09-15 10:02", 31_500_000),
        app("a4", "Pages.app", "2026-08-28 14:20", 512_000_000),
        app("a5", "Preview.app", "2026-09-15 10:02", 22_100_000),
        folder("fonts", "Fonts", "lib", "2026-08-11 11:03"),
        Row(
            id: "f1", name: "Inter-Variable.ttf", parent: "fonts", date: "2026-08-11 11:03",
            size: 804_000, kindDescription: "TrueType font"),
        folder("syslib", "Library", "sys", "2026-09-15 10:02"),
    ]

    private static let home = [
        folder("home", "Home", "users", "2026-10-25 18:40"),
        folder("shared", "Shared", "users", "2026-05-19 12:00"),
        folder("desktop", "Desktop", "home", "2026-10-25 18:31"),
        folder("documents", "Documents", "home", "2026-10-24 21:05"),
        folder("downloads", "Downloads", "home", "2026-10-25 17:52"),
        folder("movies", "Movies", "home", "2026-07-04 20:11"),
        folder("music", "Music", "home", "2026-03-12 19:47"),
        folder("pictures", "Pictures", "home", "2026-10-19 13:26"),
        folder("projects", "Projects", "home", "2026-10-25 18:58"),
        Row(
            id: "d1", name: "Screenshot 2026-10-24 at 21.14.08.png", parent: "desktop",
            date: "2026-10-24 21:14", size: 1_840_000, kindDescription: "PNG image"),
        Row(
            id: "d2", name: "todo.txt", parent: "desktop", date: "2026-10-25 18:31", size: 2_300,
            kindDescription: "Plain Text document"),
    ]

    private static let documents = [
        folder("invoices", "Invoices", "documents", "2026-10-01 09:00"),
        folder("manuals", "Manuals", "documents", "2026-04-18 16:22"),
        Row(
            id: "doc1", name: "Budget 2026.xlsx", parent: "documents", date: "2026-10-24 21:05",
            size: 84_000, kindDescription: "Excel workbook"),
        Row(
            id: "doc2", name: "Notes.md", parent: "documents", date: "2026-10-23 08:47",
            size: 6_100, kindDescription: "Markdown document"),
        Row(
            id: "doc3", name: "Lease agreement.pdf", parent: "documents", date: "2026-02-14 11:30",
            size: 1_260_000, kindDescription: "PDF document"),
        Row(
            id: "doc4", name: "Presentation.key", parent: "documents", date: "2026-09-09 15:15",
            size: 18_400_000, kindDescription: "Keynote presentation"),
        Row(
            id: "inv1", name: "Invoice 2026-09.pdf", parent: "invoices", date: "2026-10-01 09:00",
            size: 212_000, kindDescription: "PDF document"),
        Row(
            id: "inv2", name: "Invoice 2026-08.pdf", parent: "invoices", date: "2026-09-01 09:00",
            size: 208_000, kindDescription: "PDF document"),
        Row(
            id: "man1", name: "Heat pump manual.pdf", parent: "manuals", date: "2026-04-18 16:22",
            size: 8_900_000, kindDescription: "PDF document"),
        Row(
            id: "dl1", name: "Xcode_26.1.xip", parent: "downloads", date: "2026-10-25 17:52",
            size: 3_420_000_000, kindDescription: "XIP archive"),
        Row(
            id: "dl2", name: "report-q3.pdf", parent: "downloads", date: "2026-10-21 10:08",
            size: 2_450_000, kindDescription: "PDF document"),
        Row(
            id: "dl3", name: "photos-export.zip", parent: "downloads", date: "2026-10-12 19:33",
            size: 486_000_000, kindDescription: "ZIP archive"),
        Row(
            id: "dl4", name: "Installer.dmg", parent: "downloads", date: "2026-09-27 12:40",
            size: 96_000_000, kindDescription: "Disk Image"),
        Row(
            id: "dl5", name: "Floor plan.pdf", parent: "downloads", date: "2026-10-25 16:20",
            size: 3_100_000, kindDescription: "PDF document"),
    ]

    private static let media = [
        Row(
            id: "mv1", name: "Ski trip.mov", parent: "movies", date: "2026-02-21 17:44",
            size: 1_200_000_000, kindDescription: "QuickTime movie"),
        Row(
            id: "mu1", name: "Demo.mp3", parent: "music", date: "2026-03-12 19:47", size: 7_300_000,
            kindDescription: "MP3 audio"),
        folder("holiday", "Holiday 2026", "pictures", "2026-08-30 20:15"),
        Row(
            id: "pic1", name: "Wallpaper.jpg", parent: "pictures", date: "2026-10-19 13:26",
            size: 4_100_000, kindDescription: "JPEG image"),
        Row(
            id: "h1", name: "IMG_0412.heic", parent: "holiday", date: "2026-08-14 11:02",
            size: 2_900_000, kindDescription: "HEIC image"),
        Row(
            id: "h2", name: "IMG_0413.heic", parent: "holiday", date: "2026-08-14 11:03",
            size: 3_100_000, kindDescription: "HEIC image"),
        Row(
            id: "h3", name: "IMG_0431.heic", parent: "holiday", date: "2026-08-16 19:48",
            size: 2_700_000, kindDescription: "HEIC image"),
    ]

    private static let projects = [
        folder("ptw", "Treewise", "projects", "2026-10-25 18:58"),
        folder("pweb", "website", "projects", "2026-10-24 22:30"),
        folder("src", "Sources", "ptw", "2026-10-25 18:58"),
        Row(
            id: "tw1", name: "Treewise.xcodeproj", parent: "ptw", date: "2026-10-25 18:56",
            size: 48_000, kindDescription: "Xcode Project"),
        Row(
            id: "tw2", name: "README.md", parent: "ptw", date: "2026-10-25 18:57", size: 1_900,
            kindDescription: "Markdown document"),
        Row(
            id: "s1", name: "TreewiseApp.swift", parent: "src", date: "2026-10-25 18:58",
            size: 1_200, kindDescription: "Swift source"),
        Row(
            id: "s2", name: "FileTreeView.swift", parent: "src", date: "2026-10-25 18:58",
            size: 6_400, kindDescription: "Swift source"),
        Row(
            id: "s3", name: "DetailsListView.swift", parent: "src", date: "2026-10-25 18:58",
            size: 8_900, kindDescription: "Swift source"),
        Row(
            id: "w1", name: "index.html", parent: "pweb", date: "2026-10-24 22:30", size: 14_000,
            kindDescription: "HTML document"),
        Row(
            id: "w2", name: "style.css", parent: "pweb", date: "2026-10-24 22:12", size: 5_600,
            kindDescription: "CSS document"),
    ]

    private static let external = [
        folder("scans", "Scans", "icloud", "2026-10-10 08:20"),
        Row(
            id: "icl1", name: "Shopping list.txt", parent: "icloud", date: "2026-10-25 12:04",
            size: 800, kindDescription: "Plain Text document"),
        Row(
            id: "sc1", name: "Scan 2026-10-10.pdf", parent: "scans", date: "2026-10-10 08:20",
            size: 1_100_000, kindDescription: "PDF document"),
        folder("backups", "Backups", "usb", "2026-10-18 23:00"),
        folder("footage", "Footage", "usb", "2026-09-03 14:40"),
        Row(
            id: "bk1", name: "backup-2026-10-18.zip", parent: "backups", date: "2026-10-18 23:00",
            size: 2_100_000_000, kindDescription: "ZIP archive"),
        Row(
            id: "v1", name: "Clip_001.mov", parent: "footage", date: "2026-09-03 14:40",
            size: 650_000_000, kindDescription: "QuickTime movie"),
    ]
}
