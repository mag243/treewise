#if os(macOS)
    import Foundation
    import TreewiseModuleInterface
    import os

    /// The service's side of the XPC connection: runs the modules it was given
    /// (ADR 0057).
    public final class ModuleHostServer: NSObject, NSXPCListenerDelegate, ModuleHostXPCProtocol,
        Sendable
    {
        private static let logger = Logger(
            subsystem: "me.m-domain.treewise", category: "ModuleHostServer")

        private let modules: [any NameModule]

        /// Creates a server for modules.
        public init(modules: [any NameModule]) {
            self.modules = modules
        }

        /// Accepts a connection and serves it.
        public func listener(
            _ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection
        ) -> Bool {
            connection.exportedInterface = NSXPCInterface(with: ModuleHostXPCProtocol.self)
            connection.exportedObject = self
            connection.resume()
            return true
        }

        /// Replies with the descriptions of the modules.
        public func listModules(reply: @escaping @Sendable (Data?) -> Void) {
            reply(try? ModuleWire.encode(modules.map(\.description)))
        }

        /// Runs a module and replies with its sets of values, or nil when it fails.
        public func fieldValues(
            moduleID: String, request: Data, reply: @escaping @Sendable (Data?) -> Void
        ) {
            guard let module = modules.first(where: { $0.id == moduleID }),
                let decoded = try? ModuleWire.decode(NameRequest.self, from: request)
            else {
                reply(nil)
                return
            }
            Task {
                do {
                    reply(try ModuleWire.encode(try await module.fieldValues(for: decoded)))
                } catch {
                    // The error comes from closed code, so only its type is logged.
                    Self.logger.error("Module \(moduleID) failed: \(type(of: error))")
                    reply(nil)
                }
            }
        }
    }
#endif
