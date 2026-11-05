import Foundation

extension Bundle {
    /// The bundle holding this bundle's strings in the language of `locale`, so
    /// the words of a text follow the same locale as its dates and numbers.
    /// Falls back to `self` (the development language, English) when the
    /// bundle has no strings in that language (ADR 0017).
    public func localizationBundle(for locale: Locale) -> Bundle {
        guard let language = locale.language.languageCode?.identifier,
            let path = path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path)
        else { return self }
        return bundle
    }
}
