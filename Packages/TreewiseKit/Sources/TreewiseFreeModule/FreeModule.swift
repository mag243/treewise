import Foundation
import TreewiseCore
import TreewiseModuleInterface

/// Follows a folder's pattern from names and file facts alone: it reads no contents
/// (ADR 0055, ADR 0057). It fills in the date the file suggests, what the current name
/// says, and the next number.
public struct FreeModule: NameModule {
    /// The fields it can fill.
    public static let fields = [
        NameTemplate.Field(name: "date", kind: .date),
        NameTemplate.Field(name: "text", kind: .text),
        NameTemplate.Field(name: "number", kind: .number),
    ]
    /// A name that says nothing: a device's or a program's word with at most a number or a date.
    private static let saysNothing =
        #"^(scan|img|image|dsc|document|doc|file|untitled|naamloos|unbenannt|page|foto|photo|screenshot|invoice|factuur|rechnung)?[ _-]*\(?[0-9 .-]*\)?$"#
    private static let trailingNumber = "([0-9]+)$"
    private static let trailingDate = #"[0-9]{2,4}[.-][0-9]{2}[.-][0-9]{2,4}$"#
    private static let edgeSeparators = CharacterSet(charactersIn: " -_")

    /// What this module is.
    public let description = NameModuleDescription(
        id: NameModuleDescription.freeModuleID, contentTypes: ["public.item"], neededContent: [],
        fields: fields, defaultTemplate: "{date:yyyy.MM.dd} {text}")

    /// Creates the module.
    public init() {}

    /// One set of values, from the request's facts.
    public func fieldValues(for request: NameRequest) async throws -> [[String: NameTemplate.Value]]
    {
        var values: [String: NameTemplate.Value] = [
            "number": .text(Self.nextNumber(after: request.siblingNames))
        ]
        if let date = request.suggestedDate { values["date"] = date.value }
        if let text = Self.meaningfulText(of: request.name) { values["text"] = .text(text) }
        return [values]
    }

    /// The template the names follow, if any.
    public func derivedTemplate(fromNames names: [String]) -> String? {
        TemplateDeriver.template(fromNames: names)
    }

    private static func meaningfulText(of name: String) -> String? {
        var stem = ProposedName.stem(of: name)
        for format in FileNameParts.dateFormats {
            if let rest = format.rest(afterDateIn: stem) {
                stem = rest
                break
            }
        }
        let text = stem.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: edgeSeparators)
        guard
            text.range(of: saysNothing, options: [.regularExpression, .caseInsensitive]) == nil
        else { return nil }
        return text
    }

    /// One above the highest number that ends a sibling's name, in the same width.
    private static func nextNumber(after siblings: [String]) -> String {
        let numbers = siblings.map(ProposedName.stem(of:)).compactMap { stem -> String? in
            guard stem.range(of: trailingDate, options: .regularExpression) == nil,
                let range = stem.range(of: trailingNumber, options: .regularExpression)
            else { return nil }
            return String(stem[range])
        }
        guard let highest = numbers.max(by: { (Int($0) ?? 0) < (Int($1) ?? 0) }) else { return "1" }
        let next = String((Int(highest) ?? 0) + 1)
        return String(repeating: "0", count: max(0, highest.count - next.count)) + next
    }
}
