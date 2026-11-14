/// A field a template's folder names can hold (ADR 0096).
public enum FolderTemplateField: String, Codable, Hashable, Sendable {
    /// `{year}` or `{year:yy}`.
    case year
    /// `{text}`, in a case or as typed.
    case text
    /// `{seq}`, in the root only.
    case number
    /// `{date}`, in a date format of name patterns.
    case date
}

/// What a template's fields are filled in with, from the sheet (ADR 0096). A field without a
/// value stays as written.
public struct FolderTemplateValues: Codable, Hashable, Sendable {
    /// A number and the least digits it is written in, as `0143`.
    public struct Number: Codable, Hashable, Sendable {
        /// The number.
        public let value: Int
        /// The least number of digits, with leading zeros.
        public let width: Int

        /// A number written in at least `width` digits.
        public init(value: Int, width: Int) {
            self.value = value
            self.width = width
        }

        /// The number in its width.
        var written: String {
            let digits = String(value)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
    }

    /// A day of the calendar, so a date means the same day wherever it is filled in.
    public struct Day: Codable, Hashable, Sendable {
        /// The year.
        public let year: Int
        /// The month, 1 to 12.
        public let month: Int
        /// The day of the month.
        public let day: Int

        /// The day `day` of `month` in `year`.
        public init(year: Int, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }
    }

    /// The year, for `{year}` and `{year:yy}`.
    public var year: Int?
    /// The text, for `{text}`.
    public var text: String?
    /// The number, for `{seq}`.
    public var number: Number?
    /// The date, for `{date}`.
    public var date: Day?
    /// The language a month's name and a text's case are written in: the app's, which the
    /// add-on's service does not share.
    public var language: MonthNames.Language

    /// Values for a template's fields.
    public init(
        year: Int? = nil, text: String? = nil, number: Number? = nil, date: Day? = nil,
        language: MonthNames.Language = .app
    ) {
        self.year = year
        self.text = text
        self.number = number
        self.date = date
        self.language = language
    }
}
