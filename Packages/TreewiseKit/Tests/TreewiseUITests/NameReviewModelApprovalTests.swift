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

/// A choice of parts and the next period in the overview (ADR 0064).
extension NameReviewModelTests {
    @Test func offersEachPartWithTheNextPeriodOfItsSeries() async {
        _ = addFile("Tax - Sales 2025.Q3.txt")
        let item = addFile("scan.txt")
        let date = SuggestedDate(year: 2026, month: 1, day: 31, source: .insideFile)
        let model = await model(host(), suggestedDate: date)
        await model.setTemplate(
            Self.free, to: "Tax - <Sales {year}.Q{seq:4}|Payroll {year}.{seq:12}|{text}>")
        let proposals = model.session?.entry(item.id)?.proposals ?? []
        #expect(
            proposals.map(\.name) == [
                "Tax - Sales 2025.Q4.txt", "Tax - Payroll 2026.01.txt", "Tax - New.txt",
            ])
        // Only the new series took its year from the file's date.
        #expect(proposals.map(\.dateSource) == [nil, .insideFile, nil])
    }
}

/// Where the fields sit in a proposed name, to mark them while it is edited.
extension NameReviewModelTests {
    @Test func marksTheFieldsOfAProposalInTheColoursOfThePattern() async {
        let item = addFile("scan.txt")
        let model = await model(
            host(answers: [
                Self.free: .success([["text": .text("New"), "number": .text("F1")]])
            ]))
        await model.setTemplate(Self.free, to: "{folder} - {number} {text} {number}")
        let name = model.session?.entry(item.id)?.currentName ?? ""
        #expect(name == "Review - F1 New F1.txt")
        let marks = model.fieldMarks(of: item.id).map { "\(name[$0.range])=\($0.colorIndex)" }
        #expect(marks == ["F1=0", "New=1", "F1=0"])
    }

    @Test func marksNothingInTheUsersOwnName() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        model.edit(item.id, to: "Doc Mine.txt")
        #expect(model.fieldMarks(of: item.id).isEmpty)
    }
}
