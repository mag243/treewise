import TreewiseFileNamePatternsModule
import TreewiseModuleInterface

/// The add-ons this build offers (ADR 0057): the free one. The official build's catalog
/// has the same shape, with the paid ones of either kind too (ADR 0091).
public enum ModuleCatalog {
    /// All add-ons, for the service that runs them.
    public static var modules: [any AddOnModule] { [FileNamePatternsModule()] }
}
