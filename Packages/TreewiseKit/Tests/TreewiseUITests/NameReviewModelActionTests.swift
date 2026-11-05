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

    @Test func aFileSystemDateWaitsForTheSecondButton() async {
        let item = addFile("scan.txt")
        let date = SuggestedDate(year: 2026, month: 1, day: 1, source: .fileSystem)
        let host = host(answers: [
            Self.free: .success([["date": date.value, "text": .text("New")]])
        ])
        let model = await model(host, suggestedDate: date)
        await model.setTemplate(Self.free, to: "{date} X {text}")
        model.approveAll()
        #expect(model.session?.entry(item.id)?.state == .pending)
        #expect(model.datesToCheck == 1)
        model.approveAllWithDatesToCheck()
        #expect(model.session?.entry(item.id)?.state == .approved)
    }

    @Test func trustingDatesInFilesIsRemembered() async {
        let item = addFile("scan.txt")
        let date = SuggestedDate(year: 2026, month: 1, day: 1, source: .insideFile)
        let host = host(answers: [
            Self.free: .success([["date": date.value, "text": .text("New")]])
        ])
        let model = await model(host, suggestedDate: date)
        await model.setTemplate(Self.free, to: "{date} X {text}")
        #expect(model.datesToCheck == 1)
        await model.setTrustsDatesInFiles(true)
        #expect(model.datesToCheck == 0)
        model.approveAll()
        #expect(model.session?.entry(item.id)?.state == .approved)
        #expect(await store.settings(forFolderAt: "review")?.trustsDatesInFiles == true)
    }

    @Test func measuresWhetherDatesInFilesAreReliable() async {
        for day in 1...6 { _ = addFile("2026-01-0\(day) a\(day).txt") }
        let host = host()
        host.setDerivedTemplate("{date} {text}", for: Self.free)
        let date = SuggestedDate(year: 2026, month: 1, day: 1, source: .insideFile)
        #expect(await !model(host, suggestedDate: date).dateInFileIsReliable)
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
}
