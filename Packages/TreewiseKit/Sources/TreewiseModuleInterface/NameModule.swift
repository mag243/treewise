import Foundation
import TreewiseCore

/// A module that finds what a file's name should say (ADR 0057). It receives data
/// and returns the values of its fields; Treewise makes the names from them with the
/// user's template. It gets no way to reach a file, and on the Mac it runs in a service
/// without access to the network or the user's files. Treewise asks it about several files
/// at the same time (ADR 0073), so it keeps no state between requests.
///
/// This interface is internal to Treewise: it has no stability promise, and the
/// official app loads no third-party modules (ADR 0055).
public protocol NameModule: Sendable {
    /// A stable id, shown with the names its values make.
    var id: String { get }
    /// What this module is, for the app to show and to know without running it.
    var description: NameModuleDescription { get }
    /// Returns ranked sets of values for an item, best first. An empty result means
    /// the module has nothing to suggest.
    func fieldValues(for request: NameRequest) async throws -> [[String: NameTemplate.Value]]
    /// The template these names in a folder follow, or nil when the module recognizes none.
    func derivedTemplate(fromNames names: [String], folderName: String) -> String?
    /// The template, for a module whose licence decides whether it recognizes one; a paid
    /// module without a licence gives none (ADR 0071).
    func derivedTemplate(fromNames names: [String], folderName: String, licence: LicenceContext)
        -> String?
    /// The templates these names might follow, the best first, for the user to pick from
    /// (ADR 0067); a module that recognizes one template gives that one.
    func derivedTemplates(fromNames names: [String], folderName: String, licence: LicenceContext)
        -> [String]
    /// What its licence lets it do, or nil when it needs no licence (ADR 0071).
    func licenceState(licence: LicenceContext) -> ModuleLicenceState?
}

extension NameModule {
    /// The id, from the description.
    public var id: String { description.id }

    /// A module starts from its default template unless it can recognize one.
    public func derivedTemplate(fromNames names: [String], folderName: String) -> String? {
        nil
    }

    /// A module that needs no licence recognizes whatever its licence.
    public func derivedTemplate(
        fromNames names: [String], folderName: String, licence: LicenceContext
    ) -> String? {
        derivedTemplate(fromNames: names, folderName: folderName)
    }

    /// The one template it recognizes, if any.
    public func derivedTemplates(
        fromNames names: [String], folderName: String, licence: LicenceContext
    ) -> [String] {
        [derivedTemplate(fromNames: names, folderName: folderName, licence: licence)]
            .compactMap(\.self)
    }

    /// A module needs no licence unless it says so.
    public func licenceState(licence: LicenceContext) -> ModuleLicenceState? {
        nil
    }
}
