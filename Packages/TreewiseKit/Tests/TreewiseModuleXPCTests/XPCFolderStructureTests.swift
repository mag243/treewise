#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseModuleInterface
    import TreewiseModuleXPC

    /// The trip to an add-on that makes folder structures and back (ADR 0091): it gets
    /// folder names only, and what it returns is checked before anything is made.
    @Suite struct XPCFolderStructureTests {
        private static let year2026 = FolderTree(
            name: "2026", folders: [FolderTree(name: "Tax"), FolderTree(name: "Summary 2026")])
        private static let licensed = LicenceContext(
            keys: ["good"], trialStarts: [:], lastSeen: nil)

        @Test func listsItWithItsKind() async throws {
            let harness = Harness(modules: [], structures: [StubStructureModule(id: "t")])
            defer { withExtendedLifetime(harness) {} }
            let modules = try await harness.host().availableModules()
            #expect(modules.map(\.id) == ["t"])
            #expect(modules.map(\.kind) == [.folderStructure])
        }

        @Test func carriesAFoldersTreeToItAndTheTemplateBack() async throws {
            let harness = Harness(modules: [], structures: [StubStructureModule(id: "t")])
            defer { withExtendedLifetime(harness) {} }
            let template = try await harness.host().template(
                moduleID: "t", from: Self.year2026, yearAbove: nil, licence: Self.licensed)
            #expect(template == StubStructureModule.template(of: Self.year2026))
        }

        @Test func carriesTheTemplateAndTheYearAndTheFoldersToMakeBack() async throws {
            let harness = Harness(modules: [], structures: [StubStructureModule(id: "t")])
            defer { withExtendedLifetime(harness) {} }
            let template = StubStructureModule.template(of: Self.year2026)
            let folders = try await harness.host().foldersToMake(
                moduleID: "t", template: template, values: FolderTemplateValues(year: 2027),
                licence: Self.licensed)
            #expect(folders == template.filling(year: 2027))
        }

        @Test func givesNothingWhileItMayNotWork() async throws {
            let harness = Harness(modules: [], structures: [StubStructureModule(id: "t")])
            defer { withExtendedLifetime(harness) {} }
            let host = harness.host()
            #expect(
                try await host.template(
                    moduleID: "t", from: Self.year2026, yearAbove: nil, licence: .none) == nil)
            #expect(
                try await host.foldersToMake(
                    moduleID: "t", template: Self.year2026, values: FolderTemplateValues(),
                    licence: .none) == nil)
        }

        @Test func refusesFoldersThatCannotBeMade() async throws {
            var stub = StubStructureModule(id: "t")
            stub.makes = FolderTree(name: "2027", folders: [FolderTree(name: "../Elsewhere")])
            let harness = Harness(modules: [], structures: [stub])
            defer { withExtendedLifetime(harness) {} }
            await #expect(throws: NameModuleHostError.invalidResponse) {
                try await harness.host().foldersToMake(
                    moduleID: "t", template: Self.year2026,
                    values: FolderTemplateValues(year: 2027),
                    licence: Self.licensed)
            }
        }

        @Test func refusesFoldersWithAFieldLeftUnfilled() async throws {
            var stub = StubStructureModule(id: "t")
            stub.makes = FolderTree(name: "2027", folders: [FolderTree(name: "Summary {text}")])
            let harness = Harness(modules: [], structures: [stub])
            defer { withExtendedLifetime(harness) {} }
            await #expect(throws: NameModuleHostError.invalidResponse) {
                try await harness.host().foldersToMake(
                    moduleID: "t", template: Self.year2026,
                    values: FolderTemplateValues(year: 2027),
                    licence: Self.licensed)
            }
        }

        @Test func takesATemplateWhoseFieldsHoldAColon() async throws {
            var stub = StubStructureModule(id: "t")
            stub.saves = FolderTree(name: "{date:yyyy-MM-dd} Shoot")
            let harness = Harness(modules: [], structures: [stub])
            defer { withExtendedLifetime(harness) {} }
            let template = try await harness.host().template(
                moduleID: "t", from: Self.year2026, yearAbove: nil, licence: Self.licensed)
            #expect(template == stub.saves)
        }

        @Test func saysWhatItsLicenceLetsItDo() async throws {
            let harness = Harness(modules: [], structures: [StubStructureModule(id: "t")])
            defer { withExtendedLifetime(harness) {} }
            #expect(
                try await harness.host().licenceState(moduleID: "t", licence: .none) == .notTried)
        }

        @Test func isNotAskedForNames() async throws {
            let harness = Harness(modules: [], structures: [StubStructureModule(id: "t")])
            defer { withExtendedLifetime(harness) {} }
            await #expect(throws: NameModuleHostError.moduleFailed) {
                try await harness.host().derivedTemplates(
                    moduleID: "t", names: ["a"], folderName: "", licence: Self.licensed)
            }
        }

        @Test func anAddOnForNamesMakesNoFolders() async throws {
            let harness = Harness(modules: [StubModule(id: "m", derived: "{text}")])
            defer { withExtendedLifetime(harness) {} }
            await #expect(throws: NameModuleHostError.moduleFailed) {
                try await harness.host().template(
                    moduleID: "m", from: Self.year2026, yearAbove: nil, licence: Self.licensed)
            }
        }
    }
#endif
