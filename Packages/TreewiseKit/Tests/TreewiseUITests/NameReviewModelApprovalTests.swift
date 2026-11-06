import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// What a changed template does to names the user already approved (ADR 0057).
extension NameReviewModelTests {
    @Test func aChangedTemplateAsksAgainForAnApprovedName() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        await model.setTemplate(Self.free, to: "Doc {text} {text}")
        model.approveAll()
        #expect(model.session?.entry(item.id)?.state == .approved)
        await model.setTemplate(Self.free, to: "Doc {text}")
        #expect(model.session?.entry(item.id)?.currentName == "Doc New.txt")
        #expect(model.session?.entry(item.id)?.state == .pending)
        #expect(!model.canApply)
    }

    @Test func aTemplateThatMakesTheSameNameKeepsItApproved() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        model.approveAll()
        // The module gives no number, so the optional part falls away and the name stays.
        await model.setTemplate(Self.free, to: "Doc {text}[ {number}]")
        #expect(model.modules.first?.origin == .user)
        #expect(model.session?.entry(item.id)?.currentName == "Doc New.txt")
        #expect(model.session?.entry(item.id)?.state == .approved)
        #expect(model.canApply)
    }

    @Test func aChangedTemplateKeepsTheUsersApprovedName() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        model.edit(item.id, to: "Mine.txt")
        model.finishEditing(item.id)
        #expect(model.approve(item.id) == nil)
        await model.setTemplate(Self.free, to: "File {text}")
        #expect(model.session?.entry(item.id)?.currentName == "Mine.txt")
        #expect(model.session?.entry(item.id)?.state == .approved)
        #expect(model.canApply)
    }
}
