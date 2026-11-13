import Foundation

extension NameTemplate {
    /// What follows a field's `:`, besides the series of `{seq}` (ADR 0064, ADR 0089).
    enum FieldFormat: Hashable, Sendable {
        /// A date's format, as `{date:yyyy.MM.dd}`.
        case date(DateTemplate)
        /// A year in two digits, `{year:yy}`.
        case twoDigitYear
        /// The folder this many levels up from the item, `{folder:2}`; 1 is the folder that
        /// holds it.
        case level(Int)
        /// Text written all small, all capitals, or each word starting with a capital.
        case textCase(TextCase)

        /// What follows a field's `:`, read for a field of this kind, or nil when the field
        /// does not take it.
        init?(_ text: String, for kind: Field.Kind) {
            switch kind {
            case .date:
                guard let template = DateTemplate(text) else { return nil }
                self = .date(template)
            case .year:
                guard text == "yy" else { return nil }
                self = .twoDigitYear
            case .fixed:
                guard text.allSatisfy({ $0.isASCII && $0.isNumber }), let level = Int(text),
                    level >= 1
                else { return nil }
                self = .level(level)
            case .text, .number:
                guard let textCase = TextCase(rawValue: text) else { return nil }
                self = .textCase(textCase)
            case .sequence:
                return nil
            }
        }

        /// The date's format, for a date field.
        var dateTemplate: DateTemplate? {
            if case .date(let template) = self { template } else { nil }
        }
    }

    /// How the text of a field is written (ADR 0089).
    enum TextCase: String, Hashable, Sendable {
        case lower, upper, title

        /// The text in this case, by the rules of `locale`. Title case raises the first
        /// letter of each word and leaves the rest as given, so `VAT` stays `VAT`.
        func apply(to text: String, locale: Locale = .current) -> String {
            switch self {
            case .lower: return text.lowercased(with: locale)
            case .upper: return text.uppercased(with: locale)
            case .title:
                return text.split(separator: " ", omittingEmptySubsequences: false).map { word in
                    word.prefix(1).uppercased(with: locale) + word.dropFirst()
                }.joined(separator: " ")
            }
        }

        /// A regular expression for a field in this case: any text for a text field, one
        /// word holding a digit for a number field.
        func pattern(text: Bool) -> String {
            switch (self, text) {
            case (.lower, true): "[^\\p{Lu}]+?"
            case (.upper, true): "[^\\p{Ll}]+?"
            case (.title, true): "[^\\p{Ll} ][^ ]*?(?: [^\\p{Ll} ][^ ]*?)*?"
            case (.lower, false): "[^ \\p{Lu}]*[0-9][^ \\p{Lu}]*"
            case (.upper, false): "[^ \\p{Ll}]*[0-9][^ \\p{Ll}]*"
            case (.title, false): "(?=[^ ]*[0-9])[^ \\p{Ll}][^ ]*"
            }
        }
    }

    /// The key under which a folder's name is passed: `folder`, or `folder:2` and higher for
    /// the folders above it (ADR 0089).
    public static func folderKey(level: Int) -> String {
        level <= 1 ? Field.folder.name : "\(Field.folder.name):\(level)"
    }

    /// The names of a folder and the folders above it, nearest first, up to its volume: in
    /// `/Volumes/T7/Clients` that is `Clients` and `T7`. A place inside an archive counts
    /// the folders in it, then the archive, then the folders it is in (ADR 0076, ADR 0089).
    public static func folderNames(of folder: FileItem.ID) -> [String] {
        let volumes = "/Volumes/"
        func parts(of path: String) -> [String] {
            let inside = path.hasPrefix(volumes) ? String(path.dropFirst(volumes.count)) : path
            return inside.split(separator: "/").map(String.init)
        }
        guard let place = ArchivePath(folder) else { return parts(of: folder.rawValue).reversed() }
        return (parts(of: place.archive.rawValue) + parts(of: place.entry)).reversed()
    }

    /// The names of the folders above an item, nearest first, by the keys a template reads
    /// them under: `folder`, `folder:2`, … (ADR 0089).
    public static func folderValues(_ names: [String]) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: names.enumerated().map {
                (folderKey(level: $0.offset + 1), $0.element)
            })
    }
}
