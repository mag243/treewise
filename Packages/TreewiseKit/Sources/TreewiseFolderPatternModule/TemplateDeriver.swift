import Foundation
import TreewiseCore

/// Recognizes the pattern a folder's names follow (ADR 0057). It reads only names.
public enum TemplateDeriver {
    /// With fewer names than this, nothing can be told apart from chance.
    private static let minimumNames = 3
    /// The share of the names that must follow a pattern, leaving room for a few exceptions.
    private static let requiredShare = 0.8
    private static let separator = " - "
    private static let wordAndNumber = #"^(.*\S)\s+([0-9]+)$"#

    /// The template the names follow, or nil when they follow none. A word or a first part
    /// that is the folder's name becomes `{folder}` (ADR 0067).
    public static func template(fromNames names: [String], folderName: String) -> String? {
        let stems = names.map(ProposedName.stem(of:))
        guard stems.count >= minimumNames else { return nil }
        let required = Int((Double(stems.count) * requiredShare).rounded(.up))
        let candidate =
            dated(stems, required: required, folderName: folderName)
            ?? wordAndNumberTemplate(stems, required: required, folderName: folderName)
        return candidate.flatMap { text in
            let parsed = NameTemplate.parse(
                text, fields: FolderPatternModule.fields + NameTemplate.Field.suppliedByTreewise)
            return (try? parsed.get()) == nil ? nil : text
        }
    }

    private static func dated(_ stems: [String], required: Int, folderName: String) -> String? {
        var best: (format: FileNameParts.DateFormat, rests: [String])?
        for format in FileNameParts.dateFormats {
            let rests = stems.compactMap { format.rest(afterDateIn: $0) }
            if rests.count > (best?.rests.count ?? 0) { best = (format, rests) }
        }
        guard let best, best.rests.count >= required else { return nil }
        let field = "{date:\(best.format.template)}"
        return shared(best.rests).map {
            "\(field) \(withFolder($0, folderName))\(separator){text}"
        } ?? "\(field) {text}"
    }

    /// The first part that nearly all names share, in names with more parts after it.
    private static func shared(_ rests: [String]) -> String? {
        let firsts = rests.compactMap { rest -> String? in
            guard let range = rest.range(of: separator) else { return nil }
            return String(rest[..<range.lowerBound])
        }
        let counts = Dictionary(firsts.map { ($0, 1) }, uniquingKeysWith: +)
        let needed = Int((Double(rests.count) * requiredShare).rounded(.up))
        return counts.first { $0.value >= needed }?.key
    }

    /// The folder's name as `{folder}`, also after a dash that follows the date.
    private static func withFolder(_ part: String, _ folderName: String) -> String {
        guard !folderName.isEmpty else { return part }
        if part == folderName { return "{folder}" }
        if part == "- " + folderName { return "- {folder}" }
        return part
    }

    private static func wordAndNumberTemplate(
        _ stems: [String], required: Int, folderName: String
    ) -> String? {
        guard let expression = try? NSRegularExpression(pattern: wordAndNumber) else { return nil }
        let words = stems.compactMap { stem -> String? in
            let whole = NSRange(stem.startIndex..., in: stem)
            guard let match = expression.firstMatch(in: stem, range: whole),
                let word = Range(match.range(at: 1), in: stem)
            else { return nil }
            return String(stem[word])
        }
        let counts = Dictionary(words.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.first { $0.value >= required }.map {
            "\(withFolder($0.key, folderName)) {seq}"
        }
    }
}
