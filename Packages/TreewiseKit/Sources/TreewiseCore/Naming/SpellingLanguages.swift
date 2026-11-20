import Foundation

/// The languages a folder's name is spelled in for rule 3 of nearly matching names (ADR 0139):
/// the user's own, from Language & Region, each the spelling checker has a dictionary for. Not
/// the spelling checker's own list, which, set to choose automatically, holds nearly every
/// language, many of which call any typo spelled correctly.
public enum SpellingLanguages {
    /// The dictionaries to ask, in the order of `preferred`, each once.
    ///
    /// - Parameters:
    ///   - preferred: The user's languages, as `Locale.preferredLanguages` gives them
    ///     (`en-NL`, `nl-NL`).
    ///   - available: The spelling checker's dictionaries (`en_GB`, `nl`).
    /// - Returns: For each preferred language, the dictionary of its region (`en_GB` for
    ///   `en-GB`) when there is one, else that of its language alone (`en`); a language with
    ///   neither is left out.
    public static func chosen(preferred: [String], available: [String]) -> [String] {
        let dictionaries = Set(available)
        var chosen: [String] = []
        for language in preferred {
            let regional = language.replacingOccurrences(of: "-", with: "_")
            let alone = String(regional.prefix { $0 != "_" })
            guard
                let dictionary = [regional, alone].first(where: dictionaries.contains),
                !chosen.contains(dictionary)
            else { continue }
            chosen.append(dictionary)
        }
        return chosen
    }
}
