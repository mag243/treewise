#if os(macOS)
    import Foundation
    import TreewiseCore
    import TreewiseModuleInterface

    /// The app's side of the XPC connection to the modules' service (ADR 0057). What
    /// comes back is not trusted: its size and number are limited, and a module that
    /// fails or stays silent gives a typed error while the app goes on.
    public actor XPCModuleHost: NameModuleHosting {
        /// The service's name, its bundle identifier inside the app.
        public static let serviceName = "me.m-domain.treewise.modulehost"
        /// How long a module may take. It runs on the device and may read a long text.
        public static let defaultTimeout = Duration.seconds(60)
        /// The largest answer accepted. Values are short, so more is a fault.
        public static let maximumResponseBytes = 1_000_000
        /// The most sets of values taken from one answer.
        public static let maximumValueSets = 50

        private let timeout: Duration
        private let makeConnection: () -> NSXPCConnection
        private var connection: NSXPCConnection?

        /// Creates a host that reaches the service bundled in the app.
        public init(timeout: Duration = defaultTimeout) {
            self.init(timeout: timeout) { NSXPCConnection(serviceName: Self.serviceName) }
        }

        /// Creates a host with its own way of connecting.
        public init(
            timeout: Duration, makeConnection: sending @escaping () -> NSXPCConnection
        ) {
            self.timeout = timeout
            self.makeConnection = makeConnection
        }

        /// The modules on offer.
        public func availableModules() async throws -> [NameModuleDescription] {
            let data = try await ask { service, reply in service.listModules(reply: reply) }
            return try decode([NameModuleDescription].self, from: data)
        }

        /// Asks a module for sets of values, in the order it gave them.
        public func fieldValues(moduleID: String, request: NameRequest) async throws
            -> [[String: NameTemplate.Value]]
        {
            let encoded = try ModuleWire.encode(request)
            let data = try await ask { service, reply in
                service.fieldValues(moduleID: moduleID, request: encoded, reply: reply)
            }
            let valueSets = try decode([[String: NameTemplate.Value]].self, from: data)
            return Array(valueSets.prefix(Self.maximumValueSets))
        }

        /// The most templates taken from one answer.
        public static let maximumTemplates = 5

        /// Asks a module which templates names might follow, the best first.
        public func derivedTemplates(
            moduleID: String, names: [String], folderName: String, licence: LicenceContext
        ) async throws -> [String] {
            let encoded = try ModuleWire.encode(
                ModuleWire.NamesOfFolder(names: names, folderName: folderName, licence: licence))
            let data = try await ask { service, reply in
                service.derivedTemplate(moduleID: moduleID, names: encoded, reply: reply)
            }
            return Array(try decode([String].self, from: data).prefix(Self.maximumTemplates))
        }

        /// Asks a module what its licence lets it do.
        public func licenceState(moduleID: String, licence: LicenceContext)
            async throws -> ModuleLicenceState?
        {
            let encoded = try ModuleWire.encode(licence)
            let data = try await ask { service, reply in
                service.licenceState(moduleID: moduleID, question: encoded, reply: reply)
            }
            return try decode([ModuleLicenceState].self, from: data).first
        }

        private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
            guard data.count <= Self.maximumResponseBytes,
                let value = try? ModuleWire.decode(type, from: data)
            else { throw NameModuleHostError.invalidResponse }
            return value
        }

        /// Sends one message and waits for its reply, the timeout or cancellation.
        private func ask(
            _ send: (any ModuleHostXPCProtocol, @escaping @Sendable (Data?) -> Void) -> Void
        ) async throws -> Data {
            let pending = PendingReply()
            let proxy = currentConnection().remoteObjectProxyWithErrorHandler { _ in
                pending.finish(.failure(NameModuleHostError.unavailable))
            }
            guard let service = proxy as? any ModuleHostXPCProtocol else {
                throw NameModuleHostError.unavailable
            }
            send(service) { pending.finish(.success($0)) }
            let timer = Task { [timeout] in
                try await Task.sleep(for: timeout)
                pending.finish(.failure(NameModuleHostError.timedOut))
            }
            defer { timer.cancel() }
            do {
                let reply = try await withTaskCancellationHandler {
                    try await pending.wait()
                } onCancel: {
                    pending.finish(.failure(CancellationError()))
                }
                guard let reply else { throw NameModuleHostError.moduleFailed }
                return reply
            } catch NameModuleHostError.unavailable {
                // A later call connects anew, which starts the service again.
                connection?.invalidate()
                connection = nil
                throw NameModuleHostError.unavailable
            }
        }

        private func currentConnection() -> NSXPCConnection {
            if let connection { return connection }
            let new = makeConnection()
            new.remoteObjectInterface = NSXPCInterface(with: ModuleHostXPCProtocol.self)
            new.resume()
            connection = new
            return new
        }
    }
#endif
