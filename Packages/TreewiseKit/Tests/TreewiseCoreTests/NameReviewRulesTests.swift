import Testing
import TreewiseCore

/// What a review looks at, and what it reads (ADR 0057).
@Suite struct NameReviewRulesTests {
    private static let fields = [
        NameTemplate.Field(name: "number", kind: .number),
        NameTemplate.Field(name: "text", kind: .text), .folder,
    ]

    private func modules() throws -> [NameReviewRules.Module] {
        [
            .init(
                id: "paid",
                template: try NameTemplate.parse("Inv {number}", fields: Self.fields).get()),
            .init(
                id: "free",
                template: try NameTemplate.parse("Doc {text}", fields: Self.fields).get()),
        ]
    }

    private func plan(
        _ name: String, kind: ItemKind = .file, scope: NameReviewRules.Scope = .wholeFolder,
        handledBy: [String] = ["paid", "free"], alwaysSkipped: Set<String> = []
    ) throws -> NameReviewRules.Plan? {
        NameReviewRules.plan(
            for: .init(name: name, kind: kind, handledBy: handledBy),
            in: .init(name: "Folder", alwaysSkipped: alwaysSkipped), scope: scope,
            modules: try modules())
    }

    /// A name with the folder above its own fits `{folder:2}` (ADR 0089).
    @Test func aNameFitsTheFolderAboveItsOwn() throws {
        let template = try NameTemplate.parse(
            "{folder:2} {text}", fields: Self.fields + [.folder]
        ).get()
        let plan = NameReviewRules.plan(
            for: .init(name: "Acme Invoice.pdf", kind: .file, handledBy: ["m"]),
            in: .init(name: "2026", alwaysSkipped: [], foldersAbove: ["Acme"]),
            scope: .wholeFolder, modules: [.init(id: "m", template: template)])
        #expect(plan?.fittingModules == ["m"])
    }

    @Test(arguments: [ItemKind.folder, .volume, .cloud, .computer, .home])
    func aWholeFolderLeavesContainersOut(_ kind: ItemKind) throws {
        #expect(try plan("Sub", kind: kind) == nil)
    }

    @Test func aWholeFolderTakesAPackage() throws {
        #expect(try plan("App.app", kind: .package) != nil)
    }

    @Test func aSelectionTakesAFolder() throws {
        #expect(try plan("Sub", kind: .folder, scope: .selection) != nil)
    }

    @Test func aFileThatDoesNotFitGoesToEveryModuleThatHandlesIt() throws {
        let plan = try plan("scan.pdf")
        #expect(plan?.modulesToAsk == ["paid", "free"])
        #expect(plan?.isHidden == false)
    }

    @Test func onlyModulesThatHandleAFileAreAsked() throws {
        #expect(try plan("scan.pdf", handledBy: ["free"])?.modulesToAsk == ["free"])
    }

    @Test func aFileNoModuleHandlesIsOutOfScope() throws {
        let plan = try plan("scan.pdf", handledBy: [])
        #expect(plan?.isOutOfScope == true)
        #expect(plan?.modulesToAsk.isEmpty == true)
    }

    @Test func aWholeFolderDoesNotReadAFileThatFits() throws {
        let plan = try plan("Inv 12.pdf")
        #expect(plan?.fittingModules == ["paid"])
        #expect(plan?.modulesToAsk.isEmpty == true)
        #expect(plan?.isHidden == true)
    }

    @Test func aFileFitsWhenOneModuleThatHandlesItAgrees() throws {
        #expect(try plan("Doc x.pdf")?.fittingModules == ["free"])
    }

    @Test func aModuleThatDoesNotHandleAFileDoesNotMakeItFit() throws {
        #expect(try plan("Inv 12.pdf", handledBy: ["free"])?.fittingModules.isEmpty == true)
    }

    @Test func aSelectionReadsAFileThatFits() throws {
        let plan = try plan("Inv 12.pdf", scope: .selection)
        #expect(plan?.fittingModules == ["paid"])
        #expect(plan?.modulesToAsk == ["paid", "free"])
        #expect(plan?.isHidden == false)
    }

    @Test func aWholeFolderHidesAFileAlwaysSkipped() throws {
        let plan = try plan("scan.pdf", alwaysSkipped: ["scan.pdf"])
        #expect(plan?.isHidden == true)
        #expect(plan?.isAlwaysSkipped == true)
        #expect(plan?.modulesToAsk.isEmpty == true)
    }

    @Test func aSelectionTreatsAFileAlwaysSkippedLikeAnyOther() throws {
        let plan = try plan("scan.pdf", scope: .selection, alwaysSkipped: ["scan.pdf"])
        #expect(plan?.isHidden == false)
        #expect(plan?.modulesToAsk == ["paid", "free"])
    }

    @Test func straySpacesThatOtherwiseFitGetARepairAndNoReading() throws {
        let plan = try plan("Inv  12.pdf")
        #expect(plan?.repair == NameProposal(name: "Inv 12.pdf", moduleID: NameProposal.treewiseID))
        #expect(plan?.fittingModules.isEmpty == true)
        #expect(plan?.modulesToAsk.isEmpty == true)
        #expect(plan?.isHidden == false)
    }

    @Test func straySpacesInANameThatDoesNotFitGetNoRepair() throws {
        let plan = try plan("other  name.pdf")
        #expect(plan?.repair == nil)
        #expect(plan?.modulesToAsk == ["paid", "free"])
    }

    @Test func aNameWithADotAndNoExtensionCanFit() throws {
        let template = try NameTemplate.parse("{text} Permit", fields: Self.fields).get()
        let plan = NameReviewRules.plan(
            for: .init(name: "2026.04.28 Permit", kind: .file, handledBy: ["m"]),
            in: .init(name: "Folder", alwaysSkipped: []), scope: .wholeFolder,
            modules: [.init(id: "m", template: template)])
        #expect(plan?.fittingModules == ["m"])
    }

    @Test func recognizesTheFolderName() throws {
        let template = try NameTemplate.parse("{folder} {number}", fields: Self.fields).get()
        let plan = NameReviewRules.plan(
            for: .init(name: "Folder 12.pdf", kind: .file, handledBy: ["m"]),
            in: .init(name: "Folder", alwaysSkipped: []), scope: .wholeFolder,
            modules: [.init(id: "m", template: template)])
        #expect(plan?.fittingModules == ["m"])
    }

    @Test func recognizesANameAsItIsShown() throws {
        let template = try NameTemplate.parse("Ref/{number}", fields: Self.fields).get()
        let plan = NameReviewRules.plan(
            for: .init(name: "Ref:12.pdf", kind: .file, handledBy: ["m"]),
            in: .init(name: "Folder", alwaysSkipped: []), scope: .wholeFolder,
            modules: [.init(id: "m", template: template)])
        #expect(plan?.fittingModules == ["m"])
    }
}
