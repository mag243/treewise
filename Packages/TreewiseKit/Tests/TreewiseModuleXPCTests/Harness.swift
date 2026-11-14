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
        let description: AddOnDescription
        var answers = true
        var answer: @Sendable (NameRequest) throws -> [[String: NameTemplate.Value]] = { _ in [] }
        var signal: RequestSignal?

        private static func describe(
            _ id: String, neededContent: Set<ModuleContentKind> = []
        ) -> AddOnDescription {
            AddOnDescription(
                id: id, contentTypes: ["public.data"], neededContent: neededContent,
                fields: [NameTemplate.Field(name: "text", kind: .text)], defaultTemplate: "{text}")
        }

        var derived: String?
        /// Templates it gives after its derived one.
        var alternatives: [String] = []
        /// Whether it needs a licence, which a key "good" gives.
        var needsLicence = false

        init(id: String, needsLicence: Bool) {
            description = Self.describe(id)
            self.needsLicence = needsLicence
        }

        func licenceState(licence: LicenceContext) -> ModuleLicenceState? {
            guard needsLicence else { return nil }
            if licence.keys.contains("good") { return .licensed(licensee: "Ada") }
            return licence.trialStart(of: description.id) == nil ? .notTried : .unlicensed
        }

        /// With the year before, a template that tells the year and those names.
        func derivedTemplates(
            fromNames names: [String], folderName: String, years: FolderYears?,
            licence: LicenceContext
        ) -> [String] {
            guard let years else {
                return derivedTemplates(fromNames: names, folderName: folderName, licence: licence)
            }
            return ["\(years.year) " + years.namesYearBefore.joined(separator: " ")]
        }

        /// The derived template and the alternatives after it.
        func derivedTemplates(
            fromNames names: [String], folderName: String, licence: LicenceContext
        ) -> [String] {
            [derivedTemplate(fromNames: names, folderName: folderName, licence: licence)]
                .compactMap(\.self) + alternatives
        }

        /// The scripted template, or none without a licence when it needs one.
        func derivedTemplate(
            fromNames names: [String], folderName: String, licence: LicenceContext
        ) -> String? {
            if needsLicence, !licence.keys.contains("good") { return nil }
            return derivedTemplate(fromNames: names, folderName: folderName)
        }

        /// A module that reads the same folder a year before (ADR 0090).
        init(readingTheYearBefore id: String) {
            let plain = Self.describe(id)
            description = AddOnDescription(
                id: id, contentTypes: plain.names.contentTypes, neededContent: [],
                fields: plain.names.fields, defaultTemplate: plain.names.defaultTemplate,
                readsYearBefore: true)
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

    /// An add-on that makes folder structures: with the key "good" it writes each year in a
    /// name as `{year}` and fills it in again; it was never tried without one.
    struct StubStructureModule: FolderStructureModule {
        let description: AddOnDescription
        /// What it returns to make, in place of the template filled in.
        var makes: FolderTree?
        /// What it returns as a template, in place of the years written as `{year}`.
        var saves: FolderTree?

        init(id: String) {
            description = AddOnDescription(id: id, kind: .folderStructure)
        }

        static func template(of tree: FolderTree) -> FolderTree {
            FolderTree(
                name: tree.name.replacingOccurrences(of: "2026", with: FolderTree.yearField),
                folders: tree.folders.map(template(of:)))
        }

        func licenceState(licence: LicenceContext) -> ModuleLicenceState? {
            licence.keys.contains("good") ? .licensed(licensee: "Ada") : .notTried
        }

        func template(from tree: FolderTree, licence: LicenceContext) -> FolderTree? {
            licence.keys.contains("good") ? saves ?? Self.template(of: tree) : nil
        }

        func folders(
            making template: FolderTree, values: FolderTemplateValues, licence: LicenceContext
        ) -> FolderTree? {
            guard licence.keys.contains("good") else { return nil }
            return makes ?? template.filling(values)
        }
    }

    /// A server on an anonymous listener: real XPC, without a separate process.
    final class Harness: NSObject, NSXPCListenerDelegate {
        private let server: ModuleHostServer
        private let listener = NSXPCListener.anonymous()
        private let signal = RequestSignal()
        private var connections: [NSXPCConnection] = []

        init(modules: [StubModule], structures: [StubStructureModule] = []) {
            let signal = signal
            let namers: [any AddOnModule] = modules.map { module in
                var module = module
                module.signal = signal
                return module
            }
            server = ModuleHostServer(modules: namers + structures)
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
