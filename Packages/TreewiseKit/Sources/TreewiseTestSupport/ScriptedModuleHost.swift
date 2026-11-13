import Foundation
import Synchronization
import TreewiseCore
import TreewiseModuleInterface

/// A module host that answers from a script, for tests of what uses modules.
public final class ScriptedModuleHost: NameModuleHosting {
    private let modules: [NameModuleDescription]
    private let answers: [String: Result<[[String: NameTemplate.Value]], NameModuleHostError>]
    private let received = Mutex<[NameRequest]>([])
    private let templates = Mutex<[String: [String]]>([:])
    private let licences = Mutex<[String: ModuleLicenceState]>([:])
    private let askedKeys = Mutex<[[String]]>([])
    private let askedNames = Mutex<[[String]]>([])
    private let askedYears = Mutex<[(moduleID: String, years: FolderYears?)]>([])
    private let gate = Mutex(Gate())

    /// The requests being answered, and those held back until enough are open.
    private struct Gate {
        var threshold: Int?
        var total = 0
        var started: [(moduleID: String, id: String)] = []
        var open: [String: Int] = [:]
        var mostOpen: [String: Int] = [:]
        var held: [CheckedContinuation<Void, Never>] = []
    }

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

    /// The templates modules derive, by module id: the first of each module's.
    public var derivedTemplates: [String: String] {
        templates.withLock { $0.compactMapValues(\.first) }
    }
    /// Scripts the template a module derives.
    public func setDerivedTemplate(_ template: String, for moduleID: String) {
        templates.withLock { $0[moduleID] = [template] }
    }
    /// Scripts the templates a module derives, the best first.
    public func setDerivedTemplates(_ list: [String], for moduleID: String) {
        templates.withLock { $0[moduleID] = list }
    }

    /// The names each question for templates carried, in order.
    public var namesAskedAbout: [[String]] { askedNames.withLock { $0 } }
    /// The years each question for templates carried, by module id, in order.
    public var yearsAskedAbout: [(moduleID: String, years: FolderYears?)] {
        askedYears.withLock { $0 }
    }

    /// The scripted templates, if any.
    public func derivedTemplates(
        moduleID: String, names: [String], folderName: String, years: FolderYears?,
        licence: LicenceContext
    ) async throws -> [String] {
        askedNames.withLock { $0.append(names) }
        askedYears.withLock { $0.append((moduleID, years)) }
        return templates.withLock { $0[moduleID] ?? [] }
    }

    /// The keys each licence question carried, in order.
    public var licenceKeys: [[String]] { askedKeys.withLock { $0 } }
    /// Scripts a module's licence state; a module without one needs no licence.
    public func setLicenceState(_ state: ModuleLicenceState, for moduleID: String) {
        licences.withLock { $0[moduleID] = state }
    }

    /// Records the keys and gives the scripted licence state, if any.
    public func licenceState(moduleID: String, licence: LicenceContext)
        async throws -> ModuleLicenceState?
    {
        askedKeys.withLock { $0.append(licence.keys) }
        return licences.withLock { $0[moduleID] }
    }

    /// The scripted modules.
    public func availableModules() async throws -> [NameModuleDescription] { modules }

    /// How long answers are held at most. A caller that keeps enough requests open never
    /// meets it; one that asks one at a time then gets its answers, and fails its test
    /// on the count instead of hanging.
    public static let longestHold = Duration.seconds(10)

    /// Holds each answer back until `count` requests are open at once, or until all
    /// `total` requests have arrived; so a test sees how many the caller keeps open.
    public func holdAnswers(untilOpen count: Int, total: Int) {
        gate.withLock {
            $0.threshold = count
            $0.total = total
        }
        Task {
            try? await Task.sleep(for: Self.longestHold)
            releaseAll()
        }
    }

    private func releaseAll() {
        let held = gate.withLock { gate -> [CheckedContinuation<Void, Never>] in
            gate.threshold = nil
            defer { gate.held = [] }
            return gate.held
        }
        for continuation in held { continuation.resume() }
    }

    /// The most requests that were open at once, by module id.
    public var mostOpenAtOnce: [String: Int] { gate.withLock { $0.mostOpen } }
    /// The ids of the items a module was asked about, in the order the requests arrived.
    public func askedOrder(of moduleID: String) -> [String] {
        gate.withLock { $0.started.filter { $0.moduleID == moduleID }.map(\.id) }
    }

    /// Records the request and gives the scripted answer, held back while asked to.
    public func fieldValues(moduleID: String, request: NameRequest) async throws
        -> [[String: NameTemplate.Value]]
    {
        received.withLock { $0.append(request) }
        await arrive(moduleID: moduleID, id: request.id)
        gate.withLock { $0.open[moduleID, default: 0] -= 1 }
        return try (answers[moduleID] ?? .failure(.moduleFailed)).get()
    }

    private func arrive(moduleID: String, id: String) async {
        await withCheckedContinuation { continuation in
            let released = gate.withLock { gate -> [CheckedContinuation<Void, Never>] in
                gate.started.append((moduleID, id))
                gate.open[moduleID, default: 0] += 1
                gate.mostOpen[moduleID] = max(
                    gate.mostOpen[moduleID] ?? 0, gate.open[moduleID] ?? 0)
                let openNow = gate.open.values.reduce(0, +)
                guard let threshold = gate.threshold, openNow < threshold,
                    gate.started.count < gate.total
                else {
                    defer { gate.held = [] }
                    return gate.held + [continuation]
                }
                gate.held.append(continuation)
                return []
            }
            for waiting in released { waiting.resume() }
        }
    }
}
