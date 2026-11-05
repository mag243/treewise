import Testing
import TreewiseUI

extension Tag {
    /// Tests of translated texts and plural forms, which need a compiled String Catalog.
    @Tag static var localization: Tag
}

extension Trait where Self == ConditionTrait {
    /// Runs a test only when the toolchain compiled the UI's String Catalog
    /// (Xcode 27 does; the CI runner's Xcode 26.6 does not, ADR 0012).
    static var needsCompiledStrings: Self {
        .enabled(
            if: UIResources.localizations.contains("nl"),
            "this toolchain does not compile String Catalogs in swift test")
    }
}
