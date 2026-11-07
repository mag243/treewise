#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseModuleInterface
    import TreewiseModuleXPC

    /// The trip to the modules' process and back, over a real XPC connection inside
    /// the test process (ADR 0057).
    @Suite struct XPCModuleHostTests {
        private let request = NameRequest(
            id: "1", name: "a.pdf", contentType: "com.adobe.pdf", byteCount: 1, created: nil,
            modified: nil, siblingNames: ["b.pdf"], content: ModuleContent(text: "Invoice"))

        @Test func listsTheModules() async throws {
            let harness = Harness(modules: [StubModule(id: "m", neededContent: [.text])])
            defer { withExtendedLifetime(harness) {} }
            let modules = try await harness.host().availableModules()
            #expect(modules == [StubModule(id: "m", neededContent: [.text]).description])
        }

        @Test func carriesTheKeysToTheModuleAndItsLicenceStateBack() async throws {
            let harness = Harness(modules: [StubModule(id: "m", needsLicence: true)])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            #expect(
                try await host.licenceState(moduleID: "m", keys: ["bad", "good"], trialStart: nil)
                    == .licensed(licensee: "Ada"))
            #expect(
                try await host.licenceState(moduleID: "m", keys: [], trialStart: Date())
                    == .unlicensed)
        }

        @Test func aModuleWithoutALicenceGivesNoState() async throws {
            let harness = Harness(modules: [StubModule(id: "m", needsLicence: false)])
            defer { withExtendedLifetime(harness) {} }
            #expect(
                try await harness.host().licenceState(moduleID: "m", keys: [], trialStart: nil)
                    == nil)
        }

        @Test func carriesTheRequestToTheModuleAndTheProposalsBack() async throws {
            let harness = Harness(modules: [
                StubModule(id: "m") { [["text": .text($0.content.text ?? "")]] }
            ])
            defer { withExtendedLifetime(harness) {} }
            let proposals = try await harness.host().fieldValues(moduleID: "m", request: request)
            #expect(proposals == [["text": .text("Invoice")]])
        }

        @Test func carriesALargeRequest() async throws {
            let large = NameRequest(
                id: "1", name: "a", contentType: "public.data", byteCount: nil, created: nil,
                modified: nil, siblingNames: [],
                content: ModuleContent(pageImages: [Data(count: 20_000_000)]))
            let harness = Harness(modules: [
                StubModule(id: "m") {
                    [["size": .text("\($0.content.pageImages?.first?.count ?? 0)")]]
                }
            ])
            defer { withExtendedLifetime(harness) {} }
            let proposals = try await harness.host().fieldValues(moduleID: "m", request: large)
            #expect(proposals == [["size": .text("20000000")]])
        }

        @Test func carriesADerivedTemplate() async throws {
            let harness = Harness(modules: [StubModule(id: "m", derived: "{text}")])
            defer { withExtendedLifetime(harness) {} }
            let template = try await harness.host().derivedTemplate(
                moduleID: "m", names: ["a"], folderName: "")
            #expect(template == "{text}")
        }

        @Test func carriesTheFolderNameToTheModule() async throws {
            let harness = Harness(modules: [StubModule(id: "m", derived: "{text}")])
            defer { withExtendedLifetime(harness) {} }
            let template = try await harness.host().derivedTemplate(
                moduleID: "m", names: ["a"], folderName: "Tax")
            #expect(template == "Tax {text}")
        }

        @Test func aModuleWithoutADerivedTemplateGivesNone() async throws {
            let harness = Harness(modules: [StubModule(id: "m")])
            defer { withExtendedLifetime(harness) {} }
            #expect(
                try await harness.host().derivedTemplate(
                    moduleID: "m", names: ["a"], folderName: "") == nil)
        }

        @Test func anUnknownModuleFails() async {
            let harness = Harness(modules: [])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            await #expect(throws: NameModuleHostError.moduleFailed) {
                try await host.fieldValues(moduleID: "gone", request: request)
            }
        }

        @Test func aFailingModuleFails() async {
            let harness = Harness(modules: [StubModule(id: "m") { _ in throw StubError.failed }])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            await #expect(throws: NameModuleHostError.moduleFailed) {
                try await host.fieldValues(moduleID: "m", request: request)
            }
        }

        @Test func aModuleThatDoesNotAnswerTimesOut() async {
            let harness = Harness(modules: [StubModule(id: "m", answers: false)])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host(timeout: .milliseconds(20))
            await #expect(throws: NameModuleHostError.timedOut) {
                try await host.fieldValues(moduleID: "m", request: request)
            }
        }

        @Test func aStoppedProcessGivesUnavailable() async throws {
            let harness = Harness(modules: [StubModule(id: "m", answers: false)])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            let request = request
            let answer = Task { try await host.fieldValues(moduleID: "m", request: request) }
            await harness.waitForRequest()
            harness.dropConnections()
            await #expect(throws: NameModuleHostError.unavailable) { try await answer.value }
        }

        @Test func reconnectsAfterTheProcessStopped() async throws {
            let harness = Harness(modules: [StubModule(id: "m", neededContent: [])])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            _ = try await host.availableModules()
            harness.dropConnections()
            // The failure may or may not be seen first, depending on the timing.
            _ = try? await host.availableModules()
            #expect(try await host.availableModules().count == 1)
        }

        @Test func refusesAnAnswerThatIsTooLarge() async {
            let long = String(repeating: "a", count: XPCModuleHost.maximumResponseBytes + 1)
            let harness = Harness(modules: [
                StubModule(id: "m") { _ in [["text": .text(long)]]
                }
            ])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            await #expect(throws: NameModuleHostError.invalidResponse) {
                try await host.fieldValues(moduleID: "m", request: request)
            }
        }

        @Test func keepsOnlyTheFirstProposalsOfALongAnswer() async throws {
            let many = (0...XPCModuleHost.maximumValueSets).map {
                ["number": NameTemplate.Value.text("\($0)")]
            }
            let harness = Harness(modules: [StubModule(id: "m") { _ in many }])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            let proposals = try await host.fieldValues(moduleID: "m", request: request)
            #expect(proposals.count == XPCModuleHost.maximumValueSets)
        }

        @Test func cancellingEndsTheWait() async {
            let harness = Harness(modules: [StubModule(id: "m", answers: false)])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            let request = request
            let task = Task { try await host.fieldValues(moduleID: "m", request: request) }
            await harness.waitForRequest()
            task.cancel()
            await #expect(throws: CancellationError.self) { try await task.value }
        }
    }
#endif
