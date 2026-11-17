import TreewiseCore

/// The colours of the parts of a pattern and of a name, which both apps draw in their own
/// colour types (ADR 0064, 0130): each field of a pattern in a hue of its own, the same in
/// the pattern and in the name it filled, see-through so the text stays readable; a gap
/// and a date to check in the system's accent and orange.
public enum NameColors {
    /// A hue of the fields' series.
    public enum Hue: Hashable, Sendable {
        /// The yellow of Treewise's icon (`treewiseYellow`).
        case treewiseYellow
        case green, purple, pink, teal, brown
    }

    /// Treewise's yellow, as red, green and blue in sRGB.
    public static let treewiseYellow = (red: 247.0 / 255, green: 200.0 / 255, blue: 67.0 / 255)
    /// The fields' hues in turn; blue and orange are left out, as they mean a gap and a
    /// date to check.
    public static let fieldHues: [Hue] = [.treewiseYellow, .green, .purple, .pink, .teal, .brown]
    /// How opaque a field's colour is in light and in dark appearance.
    public static let fieldOpacity = (light: 0.45, dark: 0.35)
    /// How opaque a gap's and a date's colour is.
    public static let lookOpacity = 0.25

    /// The hue of the field at this place among a pattern's fields.
    public static func fieldHue(_ index: Int) -> Hue {
        fieldHues[index % fieldHues.count]
    }
}

/// A coloured stretch of a pattern or a name.
public struct NameMark: Hashable, Sendable {
    /// What a stretch is coloured for.
    public enum Tint: Hashable, Sendable {
        /// The field at this place in the pattern's order (ADR 0064).
        case field(Int)
        /// A gap for the user to fill in.
        case gap
        /// A date that comes from the file, to be checked (ADR 0058).
        case dateToCheck
    }

    public let range: Range<String.Index>
    public let tint: Tint

    public init(range: Range<String.Index>, tint: Tint) {
        self.range = range
        self.tint = tint
    }

    /// The fields of a pattern's text, each coloured by the place its key first takes.
    public static func inPattern(_ text: String) -> [NameMark] {
        let order = NameTemplate.fieldOrder(in: text)
        return NameTemplate.fieldTokens(in: text).map {
            NameMark(range: $0.range, tint: .field(order.firstIndex(of: $0.key) ?? 0))
        }
    }

    /// The gap of a name, or its date when the date came from the file and needs a look.
    public static func look(in name: String, dateFromFile: Bool) -> [NameMark] {
        guard let mark = NameReviewLook.mark(in: name, dateFromFile: dateFromFile) else {
            return []
        }
        switch mark.kind {
        case .gap: return [NameMark(range: mark.range, tint: .gap)]
        case .dateToCheck: return [NameMark(range: mark.range, tint: .dateToCheck)]
        }
    }

    /// The fields a proposal's module filled in, as the overview colours them.
    public static func fields(_ marks: [NameFieldMark]) -> [NameMark] {
        marks.map { NameMark(range: $0.range, tint: .field($0.colorIndex)) }
    }
}
