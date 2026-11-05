import TreewiseCore

/// A module that finds what a file's name should say (ADR 0057). It receives data
/// and returns the values of its fields; Treewise makes the names from them with the
/// user's template. It gets no way to reach a file, and on the Mac it runs in a service
/// without access to the network or the user's files.
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
}

extension NameModule {
    /// The id, from the description.
    public var id: String { description.id }
}
