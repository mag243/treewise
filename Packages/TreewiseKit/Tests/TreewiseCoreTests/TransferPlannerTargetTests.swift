import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

/// Which drops are allowed at all (PLAN.md §4.1).
@Suite struct TransferPlannerTargetTests {
    @Test(arguments: [DropModifiers(), .option, .command])
    func rejectsDroppingAFolderOntoItself(_ modifiers: DropModifiers) {
        #expect(planDrag(["projects"], onto: "projects", modifiers) == nil)
    }

    @Test(arguments: [DropModifiers(), .option, .command])
    func rejectsDropIntoOwnSubfolder(_ modifiers: DropModifiers) {
        #expect(planDrag(["projects"], onto: "src", modifiers) == nil)
    }

    @Test(arguments: [DropModifiers(), .option, .command])
    func rejectsAFileAsTarget(_ modifiers: DropModifiers) {
        #expect(planDrag(["doc2"], onto: "doc1", modifiers) == nil)
    }

    @Test(arguments: [DropModifiers(), .option, .command])
    func rejectsThisMacAsTarget(_ modifiers: DropModifiers) {
        let fileSystem = Fixture.standard
        let items = [fileSystem["doc2"]].compactMap { $0 }
        #expect(!items.isEmpty)
        let plan = TransferPlanner.plan(
            items: items, target: .computer(locale: Locale(identifier: "en")),
            modifiers: modifiers, ancestry: fileSystem.ancestry)
        #expect(plan == nil)
    }

    @Test func rejectsAPackageAsTarget() {
        #expect(planDrag(["doc2"], onto: "a1") == nil)
    }

    @Test(arguments: [DropModifiers(), .command])
    func rejectsMovingIntoTheFolderTheItemIsAlreadyIn(_ modifiers: DropModifiers) {
        #expect(planDrag(["doc2"], onto: "documents", modifiers) == nil)
    }

    @Test func copiesIntoTheFolderTheItemIsAlreadyInWithOption() {
        #expect(planDrag(["doc2"], onto: "documents", .option) == .copy)
    }

    @Test func movesWhenOnlySomeItemsAreAlreadyInTheTarget() {
        #expect(planDrag(["doc2", "d2"], onto: "documents") == .move)
    }

    @Test func rejectsTheWholeDragWhenOneItemIsInvalid() {
        #expect(planDrag(["doc2", "projects"], onto: "src") == nil)
    }

    @Test func rejectsALocationAsDraggedItem() {
        #expect(planDrag(["usb"], onto: "documents") == nil)
    }

    @Test func rejectsADragWithoutItems() {
        #expect(planDrag([], onto: "documents") == nil)
    }
}
