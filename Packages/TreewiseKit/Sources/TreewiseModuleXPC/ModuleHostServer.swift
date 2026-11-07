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

        /// The most templates sent back for one folder.
        static let maximumTemplates = 5

        /// Replies with the templates a module recognizes in names, the best first.
        public func derivedTemplate(
            moduleID: String, names: Data, reply: @escaping @Sendable (Data?) -> Void
        ) {
            guard let module = modules.first(where: { $0.id == moduleID }),
                let decoded = try? ModuleWire.decode(ModuleWire.NamesOfFolder.self, from: names)
            else {
                reply(nil)
                return
            }
            let templates = module.derivedTemplates(
                fromNames: decoded.names, folderName: decoded.folderName, licence: decoded.licence)
            reply(try? ModuleWire.encode(Array(templates.prefix(Self.maximumTemplates))))
        }

        /// Replies with a module's licence state, as a list of at most one.
        public func licenceState(
            moduleID: String, question: Data, reply: @escaping @Sendable (Data?) -> Void
        ) {
            guard let module = modules.first(where: { $0.id == moduleID }),
                let decoded = try? ModuleWire.decode(LicenceContext.self, from: question)
            else {
                reply(nil)
                return
            }
            let state = module.licenceState(licence: decoded)
            reply(try? ModuleWire.encode([state].compactMap(\.self)))
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
