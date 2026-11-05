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
        let id: String
        var neededContent: Set<ModuleContentKind> = []
        var answers = true
        var answer: @Sendable (NameRequest) throws -> [NameProposal] = { _ in [] }
        var signal: RequestSignal?

        init(id: String, neededContent: Set<ModuleContentKind> = [], answers: Bool = true) {
            self.id = id
            self.neededContent = neededContent
            self.answers = answers
        }

        init(id: String, answer: @escaping @Sendable (NameRequest) throws -> [NameProposal]) {
            self.id = id
            self.answer = answer
        }

        func proposeNames(for request: NameRequest) async throws -> [NameProposal] {
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
