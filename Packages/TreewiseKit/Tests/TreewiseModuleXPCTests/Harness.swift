#if os(macOS)
    import Foundation
    import Synchronization
    import TreewiseCore
    import TreewiseModuleInterface
    import TreewiseModuleXPC

    enum StubError: Error {
        case failed
    }

    /// Marks the arrival of requests, for tests that act while a module is busy.
    final class RequestSignal: Sendable {
        private let stream: AsyncStream<Void>
        private let continuation: AsyncStream<Void>.Continuation

        init() {
            (stream, continuation) = AsyncStream.makeStream()
        }

        func signal() { continuation.yield() }

        func wait() async {
            var iterator = stream.makeAsyncIterator()
            await iterator.next()
        }
    }

    /// A module that answers from a closure, or never.
    struct StubModule: NameModule {
        let description: NameModuleDescription
        var answers = true
        var answer: @Sendable (NameRequest) throws -> [[String: NameTemplate.Value]] = { _ in [] }
        var signal: RequestSignal?

        private static func describe(
            _ id: String, neededContent: Set<ModuleContentKind> = []
        ) -> NameModuleDescription {
            NameModuleDescription(
                id: id, contentTypes: ["public.data"], neededContent: neededContent,
                fields: [NameTemplate.Field(name: "text", kind: .text)], defaultTemplate: "{text}")
        }

        var derived: String?
        /// Whether it needs a licence, which a key "good" gives.
        var needsLicence = false

        init(id: String, needsLicence: Bool) {
            description = Self.describe(id)
            self.needsLicence = needsLicence
        }

        func licenceState(keys: [String], trialStart: Date?) -> ModuleLicenceState? {
            guard needsLicence else { return nil }
            if keys.contains("good") { return .licensed(licensee: "Ada") }
            return trialStart == nil ? .trial(daysLeft: 14) : .unlicensed
        }

        init(id: String, derived: String) {
            description = Self.describe(id)
            self.derived = derived
        }

        /// The scripted template, after the folder's name when there is one.
        func derivedTemplate(fromNames names: [String], folderName: String) -> String? {
            derived.map { folderName.isEmpty ? $0 : "\(folderName) \($0)" }
        }

        init(id: String, neededContent: Set<ModuleContentKind> = [], answers: Bool = true) {
            description = Self.describe(id, neededContent: neededContent)
            self.answers = answers
        }

        init(
            id: String,
            answer: @escaping @Sendable (NameRequest) throws -> [[String: NameTemplate.Value]]
        ) {
            description = Self.describe(id)
            self.answer = answer
        }

        func fieldValues(for request: NameRequest) async throws -> [[String: NameTemplate.Value]] {
            signal?.signal()
            guard answers else {
                // Stays silent without holding a thread, for longer than any test runs.
                try await Task.sleep(for: .seconds(3600))
                return []
            }
            return try answer(request)
        }
    }

    /// A server on an anonymous listener: real XPC, without a separate process.
    final class Harness: NSObject, NSXPCListenerDelegate {
        private let server: ModuleHostServer
        private let listener = NSXPCListener.anonymous()
        private let signal = RequestSignal()
        private var connections: [NSXPCConnection] = []

        init(modules: [StubModule]) {
            let signal = signal
            server = ModuleHostServer(
                modules: modules.map { module in
                    var module = module
                    module.signal = signal
                    return module
                })
            super.init()
            listener.delegate = self
            listener.resume()
        }

        func listener(
            _ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection
        ) -> Bool {
            connections.append(connection)
            return server.listener(listener, shouldAcceptNewConnection: connection)
        }

        func host(timeout: Duration = .seconds(30)) -> XPCModuleHost {
            let endpoint = listener.endpoint
            return XPCModuleHost(timeout: timeout) { NSXPCConnection(listenerEndpoint: endpoint) }
        }

        func waitForRequest() async {
            await signal.wait()
        }

        func dropConnections() {
            for connection in connections { connection.invalidate() }
        }
    }
#endif
