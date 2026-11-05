#if os(macOS)
    import Foundation

    /// What the app asks the modules' service over XPC (ADR 0057). Everything travels
    /// as `ModuleWire` data: the service gets no object that leads back to the app.
    @objc public protocol ModuleHostXPCProtocol {
        /// Replies with the encoded module descriptions.
        func listModules(reply: @escaping @Sendable (Data?) -> Void)
        /// Replies with the encoded proposals, or nil when the module failed or is not known.
        func proposeNames(
            moduleID: String, request: Data, reply: @escaping @Sendable (Data?) -> Void)
    }

    /// How requests and answers are written for the trip. A binary property list
    /// keeps page images as raw bytes.
    enum ModuleWire {
        static func encode(_ value: some Encodable) throws -> Data {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            return try encoder.encode(value)
        }

        static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
            try PropertyListDecoder().decode(type, from: data)
        }
    }
#endif
