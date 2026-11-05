import TreewiseCore

/// A module that proposes file names (ADR 0057). It receives data and returns
/// proposals. It gets no way to reach a file, and on the Mac it runs in a service
/// without access to the network or the user's files.
///
/// This interface is internal to Treewise: it has no stability promise, and the
/// official app loads no third-party modules (ADR 0055).
public protocol NameModule: Sendable {
    /// A stable id, shown with the module's proposals.
    var id: String { get }
    /// The content the module wants beyond names and metadata. A request holds
    /// only what is declared here.
    var neededContent: Set<ModuleContentKind> { get }
    /// Returns proposals for an item, best first. An empty result means the
    /// module has nothing to suggest.
    func proposeNames(for request: NameRequest) async throws -> [NameProposal]
}
