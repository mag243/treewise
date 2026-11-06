import Foundation

/// A kind of personal data that should not end up in a file name by accident, as a name
/// travels with its file into cloud folders, shared folders and e-mail (ADR 0060).
public enum PersonalData: String, Hashable, Sendable, CaseIterable {
    /// An e-mail address.
    case emailAddress
    /// An IBAN whose check digits add up.
    case iban
    /// A payment card number that passes the Luhn check.
    case paymentCard
    /// A phone number: a `+` or a `0` followed by enough digits.
    case phoneNumber

    /// The kinds found in `text`, each once, in the order of `allCases`.
    ///
    /// Check digits keep invoice and customer numbers from being taken for an IBAN or a
    /// card. A number found as one kind is not looked at again, so an IBAN's last groups
    /// are not also a phone number.
    public static func found(in text: String) -> [PersonalData] {
        var remaining = text as NSString
        var found: Set<PersonalData> = []
        for kind in allCases {
            for range in kind.matches(in: remaining as String) {
                found.insert(kind)
                remaining =
                    remaining.replacingCharacters(
                        in: range, with: String(repeating: "#", count: range.length)) as NSString
            }
        }
        return allCases.filter(found.contains)
    }

    /// The fewest and most digits of a phone number, its first included.
    private static let phoneDigits = (minimum: 9, maximum: 15)
    /// The fewest and most digits of a payment card number.
    private static let cardDigits = (minimum: 13, maximum: 19)
    /// What an IBAN's number leaves over when divided by this, if its check digits add up.
    private static let ibanModulus = 97
    /// The length of the country and check digits that an IBAN's check moves to its end.
    private static let ibanPrefixLength = 4
    /// What a letter of an IBAN counts as: `A` is 10.
    private static let ibanLetterOffset = 10
    /// The letters of an IBAN, in the order that gives their value.
    private static let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    // swiftlint:disable force_try - the patterns are fixed text, so a failure is a programmer error
    private static let emailPattern = try! NSRegularExpression(
        pattern: #"[A-Z0-9._%+-]+@[A-Z0-9-]+(?:\.[A-Z0-9-]+)*\.[A-Z]{2,}"#,
        options: .caseInsensitive)
    /// Written together or in groups of four, as on a bank statement.
    private static let ibanPattern = try! NSRegularExpression(
        pattern:
            #"(?<![A-Za-z0-9])[A-Z]{2}[0-9]{2}(?:[A-Z0-9]{11,30}|(?: [A-Z0-9]{4}){2,7}(?: [A-Z0-9]{1,4})?)(?![A-Za-z0-9])"#
    )
    /// Digits with spaces or dashes, from a first digit of 2 to 6, as card numbers start.
    private static let cardPattern = try! NSRegularExpression(
        pattern: #"(?<![\w.,])[2-6][0-9 -]*[0-9](?![\w])"#)
    /// Digits with spaces, dashes and brackets, after a `+` or a `0`.
    private static let phonePattern = try! NSRegularExpression(
        pattern: #"(?<![\w+(.,])(?:\+[0-9]|\(?0)[0-9 ()-]*[0-9](?![\w])"#)
    // swiftlint:enable force_try

    private var pattern: NSRegularExpression {
        switch self {
        case .emailAddress: Self.emailPattern
        case .iban: Self.ibanPattern
        case .paymentCard: Self.cardPattern
        case .phoneNumber: Self.phonePattern
        }
    }

    private func matches(in text: String) -> [NSRange] {
        let whole = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: whole).map(\.range).filter { range in
            let match = (text as NSString).substring(with: range)
            switch self {
            case .iban: return Self.ibanCheckDigitsAddUp(match)
            case .paymentCard:
                return Self.hasDigits(match, Self.cardDigits) && Self.passesLuhn(match)
            case .phoneNumber: return Self.hasDigits(match, Self.phoneDigits)
            case .emailAddress: return true
            }
        }
    }

    private static func ibanCheckDigitsAddUp(_ text: String) -> Bool {
        let compact = text.filter { !$0.isWhitespace }
        let moved = compact.dropFirst(ibanPrefixLength) + compact.prefix(ibanPrefixLength)
        var remainder = 0
        for character in moved {
            guard let value = character.wholeNumberValue ?? letterValue(character) else {
                return false
            }
            // A letter counts as two digits.
            let shift = value >= ibanLetterOffset ? 100 : 10
            remainder = (remainder * shift + value) % ibanModulus
        }
        return remainder == 1
    }

    private static func hasDigits(_ text: String, _ count: (minimum: Int, maximum: Int)) -> Bool {
        (count.minimum...count.maximum).contains(text.count(where: \.isWholeNumber))
    }

    private static func letterValue(_ character: Character) -> Int? {
        guard let index = letters.firstIndex(of: character) else { return nil }
        return letters.distance(from: letters.startIndex, to: index) + ibanLetterOffset
    }

    private static func passesLuhn(_ text: String) -> Bool {
        let digits = text.compactMap(\.wholeNumberValue)
        let sum = digits.reversed().enumerated().reduce(0) { sum, pair in
            guard pair.offset.isMultiple(of: 2) == false else { return sum + pair.element }
            let doubled = pair.element * 2
            return sum + (doubled > 9 ? doubled - 9 : doubled)
        }
        return sum.isMultiple(of: 10)
    }
}
