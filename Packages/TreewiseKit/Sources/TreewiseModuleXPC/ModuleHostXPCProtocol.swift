#if os(macOS)
    import Foundation

    /// What the app asks the modules' service over XPC (ADR 0057). Everything travels
    /// as `ModuleWire` data: the service gets no object that leads back to the app.
    @objc public protocol ModuleHostXPCProtocol {
        /// Replies with the encoded module descriptions.
        func listModules(reply: @escaping @Sendable (Data?) -> Void)
        /// Replies with the encoded sets of values, or nil when the module failed or is not known.
        func fieldValues(
            moduleID: String, request: Data, reply: @escaping @Sendable (Data?) -> Void)
        /// Replies with an encoded list of at most one template, or nil when the module is
        /// not known.
        func derivedTemplate(
            moduleID: String, names: Data, reply: @escaping @Sendable (Data?) -> Void)
        /// Replies with an encoded list of at most one licence state, or nil when the
        /// module is not known.
        func licenceState(
            moduleID: String, question: Data, reply: @escaping @Sendable (Data?) -> Void)
    }

    /// How requests and answers are written for the trip. A binary property list
    /// keeps page images as raw bytes.
    enum ModuleWire {
        /// A folder's names and its name, for recognizing a template.
        struct NamesOfFolder: Codable {
            let names: [String]
            let folderName: String
        }

        /// The licence keys and the trial's start, for a module's licence state.
        struct LicenceQuestion: Codable {
            let keys: [String]
            let trialStart: Date?
        }

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
