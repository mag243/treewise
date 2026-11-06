import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// Names with personal data in the overview (ADR 0060).
extension NameReviewModelTests {
    private func hostProposingAnEmailAddress() -> ScriptedModuleHost {
        host(answers: [Self.free: .success([["text": .text("jan@example.com")]])])
    }

    @Test func approveAllLeavesOutANameWithPersonalData() async {
        let item = addFile("scan.txt")
        let model = await model(hostProposingAnEmailAddress())
        #expect(model.session?.entry(item.id)?.personalData == [.emailAddress])
        model.approveAll()
        #expect(model.session?.entry(item.id)?.state == .pending)
    }

    @Test func aNameWithPersonalDataCanBeApprovedOnItsOwn() async {
        let item = addFile("scan.txt")
        let model = await model(hostProposingAnEmailAddress())
        #expect(model.approve(item.id) == nil)
        #expect(model.canApply)
    }

    @Test func approveAllTakesANameWithPersonalDataWhenOnlyWarning() async {
        let item = addFile("scan.txt")
        let model = await model(hostProposingAnEmailAddress(), personalDataInNames: .onlyWarn)
        model.approveAll()
        #expect(model.session?.entry(item.id)?.state == .approved)
    }
}
