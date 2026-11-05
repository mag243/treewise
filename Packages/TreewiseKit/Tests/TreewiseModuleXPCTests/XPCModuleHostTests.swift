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
            #expect(modules == [NameModuleDescription(id: "m", neededContent: [.text])])
        }

        @Test func carriesTheRequestToTheModuleAndTheProposalsBack() async throws {
            let harness = Harness(modules: [
                StubModule(id: "m") {
                    [NameProposal(name: $0.content.text ?? "", moduleID: "m", confidence: 0.5)]
                }
            ])
            defer { withExtendedLifetime(harness) {} }
            let proposals = try await harness.host().proposeNames(moduleID: "m", request: request)
            #expect(proposals == [NameProposal(name: "Invoice", moduleID: "m", confidence: 0.5)])
        }

        @Test func carriesALargeRequest() async throws {
            let large = NameRequest(
                id: "1", name: "a", contentType: "public.data", byteCount: nil, created: nil,
                modified: nil, siblingNames: [],
                content: ModuleContent(pageImages: [Data(count: 20_000_000)]))
            let harness = Harness(modules: [
                StubModule(id: "m") {
                    [
                        NameProposal(
                            name: "\($0.content.pageImages?.first?.count ?? 0)", moduleID: "m",
                            confidence: 1)
                    ]
                }
            ])
            defer { withExtendedLifetime(harness) {} }
            let proposals = try await harness.host().proposeNames(moduleID: "m", request: large)
            #expect(proposals.first?.name == "20000000")
        }

        @Test func anUnknownModuleFails() async {
            let harness = Harness(modules: [])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            await #expect(throws: NameModuleHostError.moduleFailed) {
                try await host.proposeNames(moduleID: "gone", request: request)
            }
        }

        @Test func aFailingModuleFails() async {
            let harness = Harness(modules: [StubModule(id: "m") { _ in throw StubError.failed }])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            await #expect(throws: NameModuleHostError.moduleFailed) {
                try await host.proposeNames(moduleID: "m", request: request)
            }
        }

        @Test func aModuleThatDoesNotAnswerTimesOut() async {
            let harness = Harness(modules: [StubModule(id: "m", answers: false)])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host(timeout: .milliseconds(20))
            await #expect(throws: NameModuleHostError.timedOut) {
                try await host.proposeNames(moduleID: "m", request: request)
            }
        }

        @Test func aStoppedProcessGivesUnavailable() async throws {
            let harness = Harness(modules: [StubModule(id: "m", answers: false)])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            let request = request
            let answer = Task { try await host.proposeNames(moduleID: "m", request: request) }
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
                StubModule(id: "m") { _ in [NameProposal(name: long, moduleID: "m", confidence: 1)]
                }
            ])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            await #expect(throws: NameModuleHostError.invalidResponse) {
                try await host.proposeNames(moduleID: "m", request: request)
            }
        }

        @Test func keepsOnlyTheFirstProposalsOfALongAnswer() async throws {
            let many = (0...XPCModuleHost.maximumProposals).map {
                NameProposal(name: "\($0)", moduleID: "m", confidence: 1)
            }
            let harness = Harness(modules: [StubModule(id: "m") { _ in many }])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            let proposals = try await host.proposeNames(moduleID: "m", request: request)
            #expect(proposals.count == XPCModuleHost.maximumProposals)
        }

        @Test func cancellingEndsTheWait() async {
            let harness = Harness(modules: [StubModule(id: "m", answers: false)])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            let request = request
            let task = Task { try await host.proposeNames(moduleID: "m", request: request) }
            await harness.waitForRequest()
            task.cancel()
            await #expect(throws: CancellationError.self) { try await task.value }
        }
    }
#endif
