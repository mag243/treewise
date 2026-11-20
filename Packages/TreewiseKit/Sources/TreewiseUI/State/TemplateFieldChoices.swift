import Foundation

/// The fields Insert Field offers for a folder of a template's tree, on the Mac and the iPad
/// (ADR 0096, ADR 0100, ADR 0143): the number counts the folders beside the root, so only the
/// root takes it, and a repeat makes several folders, so only a folder below the root does.
public enum TemplateFieldChoices {
    /// A field as written in a folder's name, and its title in the menu.
    public struct Choice: Hashable, Sendable {
        public let field: String
        public let title: String
    }

    private static let number = "{seq}"
    private static let repeats: Set<String> = ["{month:MM MMMM}", "Q{quarter}", "H{half}"]

    /// Every field, in the menu's order.
    public static var all: [Choice] {
        [
            Choice(field: "{year}", title: String(localized: "Year", bundle: .module)),
            Choice(
                field: "{year:yy}", title: String(localized: "Year in Two Digits", bundle: .module)),
            Choice(field: "{text}", title: String(localized: "Text", bundle: .module)),
            Choice(field: number, title: String(localized: "Number", bundle: .module)),
            Choice(field: "{date:yyyy-MM-dd}", title: String(localized: "Date", bundle: .module)),
            Choice(
                field: "{month:MM MMMM}", title: String(localized: "Each Month", bundle: .module)),
            Choice(field: "Q{quarter}", title: String(localized: "Each Quarter", bundle: .module)),
            Choice(field: "H{half}", title: String(localized: "Each Half", bundle: .module)),
        ]
    }

    /// The fields a folder takes: the root, `atRoot`, or one below it.
    public static func offered(atRoot: Bool) -> [Choice] {
        all.filter { atRoot ? !repeats.contains($0.field) : $0.field != number }
    }

    /// A folder's name with `field` added after it, as Insert Field writes it.
    public static func name(_ name: String, adding field: String) -> String {
        name.isEmpty ? field : name + " " + field
    }
}
