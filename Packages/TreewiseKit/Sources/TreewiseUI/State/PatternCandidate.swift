import TreewiseCore

/// A template a module recognized in a folder, with how many of the folder's names fit it.
public struct PatternCandidate: Hashable, Sendable {
    /// The template's text.
    public let text: String
    /// How many of the folder's names fit it.
    public let fits: Int
    /// How many names the folder has.
    public let of: Int
}

extension NameReviewModule {
    /// How many of the folder's files fit the pattern in force, when it is the one the
    /// module recognized.
    public var recognizedFit: PatternCandidate? {
        guard origin == .derived else { return nil }
        return candidates.first { $0.text == templateText }
    }

    /// Whether the recognized pattern fits so many files that the overview need not say how
    /// many (ADR 0067); true when it says nothing of a fit.
    public var isClearlyRecognized: Bool {
        recognizedFit.map { PatternFit.isClear(fits: $0.fits, of: $0.of) } ?? true
    }
}
