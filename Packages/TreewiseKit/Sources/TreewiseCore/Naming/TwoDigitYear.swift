/// A year in two digits, as `yy` and `{year:yy}` write it: one of this century when read
/// back (ADR 0089).
enum TwoDigitYear {
    static let digits = 2
    private static let century = 100
    private static let thisCentury = 2000

    /// The last two digits of `year`, with a leading zero.
    static func write(_ year: Int) -> String {
        let digits = String(year % century)
        return digits.count < Self.digits ? "0" + digits : digits
    }

    /// The year that `text` names: in two digits one of this century, else as written.
    static func read(_ text: Substring) -> Int? {
        Int(text).map { text.count == digits ? thisCentury + $0 : $0 }
    }
}
