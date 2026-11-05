import Foundation
import Synchronization
import TreewiseCore
import TreewiseModuleInterface

/// A module host that answers from a script, for tests of what uses modules.
public final class ScriptedModuleHost: NameModuleHosting {
    private let modules: [NameModuleDescription]
    private let answers: [String: Result<[[String: NameTemplate.Value]], NameModuleHostError>]
    private let received = Mutex<[NameRequest]>([])

    /// Creates a host with modules and each module's answer. A module without an
    /// answer fails with `moduleFailed`.
    public init(
        modules: [NameModuleDescription],
        answers: [String: Result<[[String: NameTemplate.Value]], NameModuleHostError>]
    ) {
        self.modules = modules
        self.answers = answers
    }

    /// The requests received so far.
    public var requests: [NameRequest] { received.withLock { $0 } }

    /// The scripted modules.
    public func availableModules() async throws -> [NameModuleDescription] { modules }

    /// Records the request and gives the scripted answer.
    public func fieldValues(moduleID: String, request: NameRequest) async throws
        -> [[String: NameTemplate.Value]]
    {
        received.withLock { $0.append(request) }
        return try (answers[moduleID] ?? .failure(.moduleFailed)).get()
    }
}
