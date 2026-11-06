import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// The order of the add-ons in a folder (ADR 0065).
extension NameReviewModelTests {
    private func twoModules() -> ScriptedModuleHost {
        host(
            modules: [Self.freeDescription, Self.paidDescription],
            answers: [
                Self.free: .success([["text": .text("New")]]),
                Self.paid: .success([["company": .text("Acme")]]),
            ])
    }

    private func turnBothOn() async {
        await store.save(
            FolderSettings(enabledModules: [Self.free, Self.paid], templates: [:]),
            forFolderAt: "review")
    }

    @Test func theFirstModuleGivesTheFirstName() async {
        await turnBothOn()
        let item = addFile("scan.pdf")
        let model = await model(twoModules())
        #expect(model.session?.entry(item.id)?.currentName == "Doc New.pdf")
        await model.moveModule(Self.paid, to: 0)
        #expect(model.modules.map(\.id) == [Self.paid, Self.free])
        #expect(model.session?.entry(item.id)?.currentName == "Co Acme.pdf")
        model.approveAll()
        #expect(model.session?.approvedRenames.first?.to == "Co Acme.pdf")
    }

    @Test func theOrderIsRememberedForTheFolder() async {
        await turnBothOn()
        _ = addFile("scan.pdf")
        let first = await model(twoModules())
        await first.moveModule(Self.paid, to: 0)
        let again = await model(twoModules())
        #expect(again.modules.map(\.id) == [Self.paid, Self.free])
    }
}
