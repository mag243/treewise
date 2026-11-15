import Foundation
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface
import os

/// A module as the overview shows it.
public struct NameReviewModule: Identifiable, Hashable, Sendable {
    /// Where a module's template comes from.
    public enum Origin: Hashable, Sendable {
        /// Recognized in the folder's names.
        case derived
        /// The module's default.
        case moduleDefault
        /// Changed by the user.
        case user
        /// None recognized, so the default module proposes nothing until the user picks one.
        case notRecognized
        /// None recognized, and the user's own default is used because files were selected.
        case usersDefault
    }

    /// What the module is.
    public let description: AddOnDescription
    /// Whether it is on for this folder.
    public internal(set) var isOn: Bool
    /// Its template as last typed, usable or not.
    public internal(set) var templateText: String
    /// Where its template comes from.
    public internal(set) var origin: Origin
    /// Why the typed template cannot be used; the last usable one stays in force.
    public internal(set) var templateProblem: NameTemplate.Problem?
    /// The template in force.
    var template: NameTemplate?
    /// The template it had before the user changed it, if it had one.
    var recognized: String?
    /// What its licence lets it do, for a paid module; an unlicensed one is off and cannot
    /// be turned on (ADR 0071).
    public internal(set) var licence: ModuleLicenceState?
    /// The templates it recognized in the folder, the best first, to pick from (ADR 0067).
    public internal(set) var candidates: [PatternCandidate] = []
    /// How many names of the folder it was given to recognize a pattern in, those of the
    /// same folder a year before included.
    var namesGiven = 0
    /// Whether its pattern was counted against the names of the same folder a year before,
    /// as the folder holds too few of its own (ADR 0090).
    public internal(set) var recognizedInYearBefore = false

    /// Whether the folder has too few names to recognize a pattern in: fewer than
    /// `PatternFit.minimumFits` (ADR 0067).
    public var hasTooFewNamesForAPattern: Bool { namesGiven < PatternFit.minimumFits }

    /// The module's id.
    public var id: String { description.id }
}
