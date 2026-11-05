import TreewiseFolderPatternModule
import TreewiseModuleInterface

/// The modules this build offers (ADR 0057).
public enum ModuleCatalog {
    /// All modules, for the service that runs them.
    public static var modules: [any NameModule] { [FolderPatternModule()] }
}
