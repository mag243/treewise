import Foundation

/// Takes file names apart, for the file name patterns module.
enum FileNameParts {
    /// A way of writing a date at the start of a name.
    struct DateFormat: Sendable {
        /// The format as a template writes it.
        let template: String
        /// The date with its parts in groups.
        let pattern: String
        /// Which group holds the year, the month and the day.
        let order: [Int]
        /// The date at the start of a name and what follows it, compiled once.
        private let expression: NSRegularExpression

        init(template: String, pattern: String, order: [Int]) {
            self.template = template
            self.pattern = pattern
            self.order = order
            // swiftlint:disable:next force_try - fixed text; a bad pattern is a programmer error
            expression = try! NSRegularExpression(pattern: "^\(pattern)(?: +(.*))?$")
        }

        /// What follows the date at the start of a name, or nil when it starts with none.
        func rest(afterDateIn stem: String) -> String? {
            guard
                let match = expression.firstMatch(
                    in: stem, range: NSRange(stem.startIndex..., in: stem)),
                let date = date(in: match, of: stem), date.isValidDate
            else { return nil }
            let last = match.numberOfRanges - 1
            return Range(match.range(at: last), in: stem).map { String(stem[$0]) } ?? ""
        }

        private func date(in match: NSTextCheckingResult, of stem: String) -> DateComponents? {
            let parts = order.compactMap { group in
                Range(match.range(at: group), in: stem).flatMap { Int(stem[$0]) }
            }
            guard parts.count == order.count else { return nil }
            return DateComponents(
                calendar: Calendar(identifier: .gregorian), year: parts[0], month: parts[1],
                day: parts[2])
        }
    }

    /// The formats recognized. Those that start with the year come first, so a name fitting
    /// two takes the clearest.
    static let dateFormats = [
        DateFormat(
            template: "yyyy.MM.dd", pattern: #"([0-9]{4})\.([0-9]{2})\.([0-9]{2})"#,
            order: [1, 2, 3]),
        DateFormat(
            template: "yyyy-MM-dd", pattern: "([0-9]{4})-([0-9]{2})-([0-9]{2})", order: [1, 2, 3]),
        DateFormat(
            template: "yyyyMMdd", pattern: "([0-9]{4})([0-9]{2})([0-9]{2})", order: [1, 2, 3]),
        DateFormat(
            template: "dd.MM.yyyy", pattern: #"([0-9]{2})\.([0-9]{2})\.([0-9]{4})"#,
            order: [3, 2, 1]),
        DateFormat(
            template: "dd-MM-yyyy", pattern: "([0-9]{2})-([0-9]{2})-([0-9]{4})", order: [3, 2, 1]),
    ]
}
