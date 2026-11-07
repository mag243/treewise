import Foundation

/// The names of the months in the app's languages, English, Dutch and German, from
/// Treewise's own tables so a name reads the same on every Mac (ADR 0067).
public enum MonthNames {
    /// A language a month's name is written in.
    public enum Language: String, CaseIterable, Hashable, Sendable {
        case english = "en"
        case dutch = "nl"
        case german = "de"

        /// The first of the preferred languages that Treewise speaks, else English.
        public init(preferring preferred: [String]) {
            let codes = preferred.compactMap { $0.split(separator: "-").first.map(String.init) }
            self = codes.lazy.compactMap(Language.init(rawValue:)).first ?? .english
        }

        /// The language the app runs in.
        static let app = Language(preferring: Bundle.main.preferredLocalizations)
    }

    private static let full: [Language: [String]] = [
        .english: [
            "January", "February", "March", "April", "May", "June", "July", "August",
            "September", "October", "November", "December",
        ],
        .dutch: [
            "januari", "februari", "maart", "april", "mei", "juni", "juli", "augustus",
            "september", "oktober", "november", "december",
        ],
        .german: [
            "Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
            "September", "Oktober", "November", "Dezember",
        ],
    ]

    private static let short: [Language: [String]] = [
        .english: [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        ],
        .dutch: [
            "jan", "feb", "mrt", "apr", "mei", "jun", "jul", "aug", "sep", "okt", "nov", "dec",
        ],
        .german: [
            "Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez",
        ],
    ]

    /// The name of a month, 1 to 12, as its language writes it.
    /// Precondition: `month` is between 1 and 12.
    public static func name(of month: Int, short isShort: Bool, in language: Language) -> String {
        precondition((1...12).contains(month), "`month` is between 1 and 12")
        return (isShort ? short : full)[language, default: []][month - 1]
    }

    /// Every name, full or short, in any language, with its month; the longest first, so
    /// `March` is tried before `Mar`.
    private static let all: [(name: String, month: Int)] = {
        let tables = Array(full.values) + Array(short.values)
        let pairs = tables.flatMap { $0.enumerated().map { ($0.element, $0.offset + 1) } }
        var seen = Set<String>()
        return pairs.filter { seen.insert($0.0.lowercased()).inserted }
            .sorted { $0.0.count > $1.0.count }
    }()

    /// The languages that write a month's name exactly so, case and all: `maart` is Dutch,
    /// `April` English and German, `april` Dutch.
    public static func languages(writing name: String) -> Set<Language> {
        Set(
            Language.allCases.filter { language in
                full[language, default: []].contains(name)
                    || short[language, default: []].contains(name)
            })
    }

    /// The month whose name, full or short, begins the text, ignoring case, and the
    /// length of that name; nil when no name does.
    public static func month(atStartOf text: Substring) -> (month: Int, length: Int)? {
        let lowered = text.lowercased()
        for entry in all where lowered.hasPrefix(entry.name.lowercased()) {
            return (entry.month, entry.name.count)
        }
        return nil
    }

    /// A regular expression that recognizes any month's name, full or short, ignoring
    /// case; a name with an accent also as written decomposed, as a file name may be.
    static let pattern: String = {
        let names = all.flatMap { entry in
            Set([entry.name, entry.name.decomposedStringWithCanonicalMapping])
        }.sorted { $0.utf16.count > $1.utf16.count }
        return "(?i:" + names.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            + ")"
    }()
}
