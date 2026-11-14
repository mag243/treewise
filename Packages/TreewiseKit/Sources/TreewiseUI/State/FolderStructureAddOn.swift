import Foundation
import TreewiseModuleInterface

/// The add-on that makes folder structures, as Treewise asks it: the host it runs in, its id
/// and the licence it is asked with (ADR 0091, ADR 0099). Treewise has templates without it;
/// it adds recognizing fields on saving and offering a template in an empty folder.
public struct FolderStructureAddOn: Sendable {
    /// The host that runs the add-on.
    public let host: any AddOnHosting
    /// The add-on's id.
    public let moduleID: String
    /// The licence it is asked with.
    public let licence: @MainActor @Sendable () -> LicenceContext

    /// Asks `host`'s add-on `moduleID` with the licence `licence` gives.
    public init(
        host: any AddOnHosting, moduleID: String,
        licence: @escaping @MainActor @Sendable () -> LicenceContext
    ) {
        self.host = host
        self.moduleID = moduleID
        self.licence = licence
    }
}
