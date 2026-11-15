import Foundation
import TreewiseCore
import TreewiseModuleInterface

/// What entering a licence key came to (ADR 0071).
public enum LicenceKeyOutcome: Hashable, Sendable {
    /// The text is no licence key at all.
    case notAKey
    /// No add-on the app has takes it: it is for another, withdrawn or not genuine.
    case unlocksNothing
    /// An add-on could not check it, as their process could not be reached, and none
    /// unlocked it.
    case notChecked
    /// It unlocks these modules, for this licensee, and is kept.
    case unlocked(modules: [String], licensee: String)
}
