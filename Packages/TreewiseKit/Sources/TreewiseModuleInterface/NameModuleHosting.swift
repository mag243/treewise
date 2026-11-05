import TreewiseCore

/// A module as the app knows it, without running it (ADR 0057).
public struct NameModuleDescription: Hashable, Sendable, Codable {
    /// The module's id.
    public let id: String
    /// The content its requests must hold.
    public let neededContent: Set<ModuleContentKind>

    /// Creates a description.
    public init(id: String, neededContent: Set<ModuleContentKind>) {
        self.id = id
        self.neededContent = neededContent
    }
}

/// Why a module gave no answer. None of this stops the app: it goes on with the
/// proposals it has (ADR 0057).
public enum NameModuleHostError: Error, Hashable, Sendable {
    /// The modules' process could not be reached, or stopped.
    case unavailable
    /// No answer came in time.
    case timedOut
    /// The module failed, or is not known.
    case moduleFailed
    /// The answer was too large or could not be read.
    case invalidResponse
}

/// Where the app reaches its modules, wherever they run (ADR 0057).
public protocol NameModuleHosting: Sendable {
    /// The modules on offer.
    func availableModules() async throws -> [NameModuleDescription]
    /// Asks a module for proposals. A request must hold only what the module declared.
    func proposeNames(moduleID: String, request: NameRequest) async throws -> [NameProposal]
}
