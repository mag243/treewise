import Foundation

/// The resources TreewiseUI ships.
public enum UIResources {
    /// The languages whose strings the module's bundle holds. Empty when the
    /// toolchain did not compile the String Catalog, as SwiftPM 6.2's
    /// `swift test` does not (ADR 0012); the texts then fall back to English
    /// keys, plural forms included.
    public static var localizations: Set<String> {
        Set(Bundle.module.localizations)
    }
}
