import Foundation
import TreewiseCore
import TreewiseModuleInterface

/// Follows a folder's pattern from names and file facts alone: it reads no contents
/// (ADR 0055, ADR 0057). It fills in the date the file suggests and what the current name
/// says, leaving out the folder's name; the next number of a series is Treewise's `{seq}`
/// (ADR 0067).
public struct FolderPatternModule: NameModule {
    /// The fields it can fill.
    public static let fields = [
        NameTemplate.Field(name: "date", kind: .date),
        NameTemplate.Field(name: "text", kind: .text),
    ]
    /// A name that says nothing: a device's or a program's word with at most a number or a date.
    private static let saysNothing =
        #"^(scan|img|image|dsc|document|doc|file|untitled|naamloos|unbenannt|page|foto|photo|screenshot|invoice|factuur|rechnung)?[ _-]*\(?[0-9 .-]*\)?$"#
    /// What separates the parts of a name: a dash or an underscore, with or without spaces.
    private static let partSeparator = " *[-_] *"
    private static let edgeSeparators = CharacterSet(charactersIn: " -_")

    /// What this module is.
    public let description = NameModuleDescription(
        id: NameModuleDescription.defaultModuleID, contentTypes: ["public.item"], neededContent: [],
        fields: fields, defaultTemplate: "{date:yyyy.MM.dd} {text}", isFree: true,
        summaries: [
            "en": "Proposes names from a file's date and name, in the pattern its folder uses.",
            "nl":
                "Stelt namen voor uit de datum en naam van een bestand, in het patroon van de map.",
            "de": "Schlägt Namen aus Datum und Namen einer Datei vor, im Muster ihres Ordners.",
        ])

    /// Creates the module.
    public init() {}

    /// One set of values, from the request's facts.
    public func fieldValues(for request: NameRequest) async throws -> [[String: NameTemplate.Value]]
    {
        var values: [String: NameTemplate.Value] = [:]
        if let date = request.suggestedDate { values["date"] = date.value }
        if let text = Self.meaningfulText(of: request.name, folderName: request.folderName) {
            values["text"] = .text(text)
        }
        return [values]
    }

    /// The template the names follow, if any.
    public func derivedTemplate(fromNames names: [String], folderName: String) -> String? {
        TemplateDeriver.template(fromNames: names, folderName: folderName)
    }

    private static func meaningfulText(of name: String, folderName: String) -> String? {
        var stem = ProposedName.stem(of: name)
        for format in FileNameParts.dateFormats {
            if let rest = format.rest(afterDateIn: stem) {
                stem = rest
                break
            }
        }
        let text = withoutFolderName(stem, folderName)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: edgeSeparators)
        guard
            text.range(of: saysNothing, options: [.regularExpression, .caseInsensitive]) == nil
        else { return nil }
        return text
    }

    /// The text without the parts that are the folder's name, or nearly are, with the
    /// separators between the other parts as they were. Only whole parts fall away.
    private static func withoutFolderName(_ text: String, _ folderName: String) -> String {
        guard !folderName.isEmpty,
            let expression = try? NSRegularExpression(pattern: partSeparator)
        else { return text }
        var parts: [String] = []
        var separators: [String] = []
        var start = text.startIndex
        for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            parts.append(String(text[start..<range.lowerBound]))
            separators.append(String(text[range]))
            start = range.upperBound
        }
        parts.append(String(text[start...]))
        var kept = ""
        for (index, part) in parts.enumerated() {
            let isFolder = !part.isEmpty && NearlySameText.matches(part, folderName)
            if !isFolder { kept += part }
            // A part that falls away takes its separator with it.
            if index < separators.count, !isFolder || kept.isEmpty { kept += separators[index] }
        }
        return kept
    }
}
