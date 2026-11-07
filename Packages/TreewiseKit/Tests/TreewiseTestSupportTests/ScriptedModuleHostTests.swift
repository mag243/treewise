import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport

@Suite struct ScriptedModuleHostTests {
    private let request = NameRequest(
        id: "1", name: "a.pdf", contentType: "com.adobe.pdf", byteCount: nil, created: nil,
        modified: nil, siblingNames: [], content: ModuleContent())

    @Test func givesTheScriptedAnswerAndRecordsTheRequest() async throws {
        let values: [String: NameTemplate.Value] = ["number": .text("1")]
        let host = ScriptedModuleHost(modules: [], answers: ["m": .success([values])])
        #expect(try await host.fieldValues(moduleID: "m", request: request) == [values])
        #expect(host.requests == [request])
    }

    @Test func givesTheScriptedLicenceStateAndRecordsTheKeys() async throws {
        let host = ScriptedModuleHost(modules: [], answers: [:])
        host.setLicenceState(.trial(daysLeft: 5), for: "m")
        #expect(
            try await host.licenceState(
                moduleID: "m", licence: LicenceContext(keys: ["k"], trialStart: nil, lastSeen: nil))
                == .trial(daysLeft: 5))
        #expect(try await host.licenceState(moduleID: "other", licence: .none) == nil)
        #expect(host.licenceKeys == [["k"], []])
    }

    @Test func failsForAModuleWithoutAnAnswer() async {
        let host = ScriptedModuleHost(modules: [], answers: [:])
        await #expect(throws: NameModuleHostError.moduleFailed) {
            try await host.fieldValues(moduleID: "m", request: request)
        }
    }
}
