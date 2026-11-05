import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// What the user does in the review overview (ADR 0057).
extension NameReviewModelTests {
    @Test func alwaysSkippingHidesAFileAndRemembersIt() async {
        let item = addFile("Budget.txt")
        let model = await model(host())
        await model.alwaysSkip(item.id)
        #expect(model.rows.isEmpty)
        #expect(await store.settings(forFolderAt: "review")?.alwaysSkipped == ["Budget.txt"])
        await model.stopAlwaysSkipping(item.id)
        #expect(model.rows.map(\.id) == [item.id])
    }

    @Test func aConflictWithTheFolderShowsInTheRow() async {
        let item = addFile("scan.txt")
        _ = addFile("Doc New.txt")
        let model = await model(host())
        #expect(model.conflicts[item.id] == .nameTaken("Doc New.txt"))
        #expect(model.approve(item.id) != nil)
    }

    @Test func twoFilesWithOneNameConflict() async {
        let first = addFile("a.txt")
        let second = addFile("b.txt")
        let model = await model(host())
        #expect(model.conflicts[first.id] == .duplicateInBatch)
        #expect(model.conflicts[second.id] == .duplicateInBatch)
    }

    @Test func appliesApprovedNames() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        #expect(model.approve(item.id) == nil)
        #expect(model.canApply)
        await model.apply()
        #expect(model.outcome?.renamed.first?.item.name == "Doc New.txt")
        #expect(model.outcome?.failure == nil)
    }

    @Test func approveAllTakesAFileSystemDate() async {
        let item = addFile("scan.txt")
        let date = SuggestedDate(year: 2026, month: 1, day: 1, source: .fileSystem)
        let host = host(answers: [
            Self.free: .success([["date": date.value, "text": .text("New")]])
        ])
        let model = await model(host, suggestedDate: date)
        await model.setTemplate(Self.free, to: "{date} X {text}")
        model.approveAll()
        #expect(model.session?.entry(item.id)?.state == .approved)
    }

    @Test func aModuleThatFailsLeavesTheRest() async {
        let item = addFile("scan.txt")
        let model = await model(host(answers: [Self.free: .failure(.unavailable)]))
        #expect(model.session?.entry(item.id)?.proposals.isEmpty == true)
        #expect(model.moduleFailed)
    }

    @Test func selectsTheFirstRow() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        #expect(model.selectedID == item.id)
    }

    @Test func givesTheNamesAroundTheSelectedName() async {
        let item = addFile("scan.txt")
        _ = addFile("Zebra.txt")
        let model = await model(host(answers: [Self.free: .success([["text": .text("Other")]])]))
        model.selectedID = item.id
        #expect(model.neighbours.contains { $0.name == "Doc Other.txt" && $0.isNew })
    }

    @Test(arguments: [NameReviewKey.approve, .skip, .next, .previous])
    func keysLeaveARowAloneWhileTyping(_ key: NameReviewKey) async {
        let item = addFile("scan.txt")
        let model = await model(
            host(answers: [
                Self.free: .success([["text": .text("One")], ["text": .text("Two")]])
            ]))
        #expect(!model.handle(key, isTyping: true))
        #expect(model.session?.entry(item.id)?.state == .pending)
        #expect(model.session?.entry(item.id)?.currentName == "Doc One.txt")
    }

    @Test func aKeyApprovesAndMovesDown() async {
        let first = addFile("a.txt")
        let second = addFile("b.txt")
        let model = await model(
            host(answers: [Self.free: .success([["number": .text("1"), "text": .text("x")]])]))
        await model.setTemplate(Self.free, to: "{text} {number}")
        model.edit(first.id, to: "First.txt")
        model.edit(second.id, to: "Second.txt")
        model.selectedID = first.id
        #expect(model.handle(.approve, isTyping: false))
        #expect(model.session?.entry(first.id)?.state == .approved)
        #expect(model.selectedID == second.id)
    }

    @Test func rowsFollowTheNames() async {
        let later = addFile("b10.txt")
        let earlier = addFile("b9.txt")
        let model = await model(host())
        #expect(model.session?.entries.map(\.id) == [earlier.id, later.id])
    }

    @Test func aKeySkipsAndMovesDown() async {
        let first = addFile("a.txt")
        let second = addFile("b.txt")
        let model = await model(host())
        model.selectedID = first.id
        #expect(model.handle(.skip, isTyping: false))
        #expect(model.session?.entry(first.id)?.state == .skipped)
        #expect(model.selectedID == second.id)
    }

    @Test func aKeyStepsBetweenOptions() async {
        let item = addFile("scan.txt")
        let model = await model(
            host(answers: [
                Self.free: .success([["text": .text("One")], ["text": .text("Two")]])
            ]))
        #expect(model.handle(.next, isTyping: false))
        #expect(model.session?.entry(item.id)?.currentName == "Doc Two.txt")
    }

    @Test func aWholeFolderWithoutAPatternGetsNoProposals() async {
        let item = addFile("scan.txt")
        let host = ScriptedModuleHost(
            modules: [Self.freeDescription],
            answers: [Self.free: .success([["text": .text("New")]])])
        let model = await model(host)
        #expect(model.modules.first?.origin == .notRecognized)
        #expect(model.session?.entry(item.id)?.proposals.isEmpty == true)
        #expect(model.session?.entry(item.id)?.isOutOfScope == false)
        #expect(host.requests.isEmpty)
    }

    @Test func aSelectionWithoutAPatternUsesTheUsersDefault() async {
        let item = addFile("scan.txt")
        let host = ScriptedModuleHost(
            modules: [Self.freeDescription],
            answers: [Self.free: .success([["text": .text("New")]])])
        let model = await model(host, scope: .selection, selection: [item])
        #expect(model.modules.first?.origin == .usersDefault)
        #expect(model.session?.entry(item.id)?.currentName == "Std New.txt")
    }

    @Test func theUsersDefaultIsOneClickAway() async {
        let item = addFile("scan.txt")
        let host = ScriptedModuleHost(
            modules: [Self.freeDescription],
            answers: [Self.free: .success([["text": .text("New")]])])
        let model = await model(host)
        await model.useDefaultPattern(Self.free)
        await model.waitUntilRead()
        #expect(model.session?.entry(item.id)?.currentName == "Std New.txt")
        #expect(await store.settings(forFolderAt: "review")?.templates[Self.free] == "Std {text}")
    }

    @Test func aPaidModuleStartsFromItsOwnDefault() async {
        _ = addFile("scan.pdf")
        await store.save(
            FolderSettings(enabledModules: [Self.paid], templates: [:]), forFolderAt: "review")
        let host = ScriptedModuleHost(
            modules: [Self.paidDescription],
            answers: [Self.paid: .success([["company": .text("North")]])])
        let model = await model(host)
        #expect(model.modules.first?.origin == .moduleDefault)
        #expect(model.modules.first?.templateText == "Co {company}")
    }
}
