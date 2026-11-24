import Foundation

/// How a file's icon looks on the iPad and the iPhone (ADR 0151): one of Treewise's own,
/// a page with its kind's colour and its extension, or the system's.
public enum FileIconLook: String, CaseIterable, Sendable {
    /// A neutral page with a label in the kind's colour sticking out at its left.
    case pageWithLabel
    /// A light page with a band in the kind's colour holding the extension.
    case pageWithBand
    /// A page filled with the kind's colour, the extension on it.
    case filledPage
    /// The icon Quick Look gives for the type, as Files shows it.
    case system
}
