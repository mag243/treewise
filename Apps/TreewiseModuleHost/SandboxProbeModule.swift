#if TREEWISE_PROBE
    import Foundation
    import TreewiseCore
    import TreewiseModuleInterface

    /// A module that tries what the service's sandbox must forbid, for the probe build
    /// only (`tools/build.sh probe`): reading a file and a folder outside its container,
    /// and opening a connection. It answers with the error of each try, so the app can
    /// tell the sandbox's denial from a path that is wrong.
    struct SandboxProbeModule: NameModule {
        /// The id the app asks for.
        static let id = "me.m-domain.treewise.sandbox-probe"

        let description = NameModuleDescription(
            id: Self.id, contentTypes: ["public.item"], neededContent: [], fields: [],
            defaultTemplate: "{text}", isFree: true)

        /// The request's name is the file to read, and its sibling names are the folder
        /// to list and the addresses to connect to, as `host:port`.
        func fieldValues(for request: NameRequest) async throws -> [[String: NameTemplate.Value]] {
            var values: [String: NameTemplate.Value] = [
                SandboxProbe.readKey: .text(SandboxProbe.read(request.name))
            ]
            if let folder = request.siblingNames.first {
                values[SandboxProbe.listKey] = .text(SandboxProbe.list(folder))
            }
            for (index, address) in request.siblingNames.dropFirst().enumerated() {
                values[SandboxProbe.connectKey(index)] = .text(SandboxProbe.connect(address))
            }
            return [values]
        }
    }
#endif
