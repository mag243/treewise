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
        #expect(marks == ["Review=0", "F1=1", "New=2", "F1=1"])
    }

    @Test func marksNothingInTheUsersOwnName() async {
        let item = addFile("scan.txt")
        let model = await model(host())
        model.edit(item.id, to: "Doc Mine.txt")
        #expect(model.fieldMarks(of: item.id).isEmpty)
    }
}

/// A pattern has no spaces at its ends (ADR 0057).
extension NameReviewModelTests {
    @Test func keepsAPatternWithoutSpacesAtItsEnds() async {
        _ = addFile("scan.txt")
        let model = await model(host())
        await model.setTemplate(Self.free, to: " Doc {text} ")
        #expect(model.modules.first?.templateText == "Doc {text}")
        #expect(await store.settings(forFolderAt: "review")?.templates[Self.free] == "Doc {text}")
    }
}

/// What a module is told of the folder (ADR 0067).
extension NameReviewModelTests {
    @Test func tellsTheModuleTheFoldersNameAndPattern() async {
        _ = addFile("scan.txt")
        let host = host()
        _ = await model(host)
        #expect(host.requests.last?.folderName == "Review")
        #expect(host.requests.last?.pattern == "Doc {text}")
    }
}

/// Picking and saving patterns in the add-ons header (ADR 0068).
extension NameReviewModelTests {
    @Test func offersTheSavedPatternsWithThoseAnAddOnCannotUse() async throws {
        _ = addFile("scan.txt")
        let model = await model(host())
        let choices = model.savedPatternChoices(for: Self.free)
        #expect(choices.map(\.pattern.name) == ["Doc", "Company"])
        #expect(choices.map(\.problem) == [nil, .unknownField("company")])
        #expect(choices.map(\.isCurrent) == [true, false])
    }

    @Test func usesASavedPatternInThisFolder() async throws {
        let item = addFile("scan.txt")
        let model = await model(host())
        await model.setTemplate(Self.free, to: "Other {text}")
        let doc = try #require(model.savedPatternChoices(for: Self.free).first)
        await model.useSavedPattern(doc.pattern.id, for: Self.free)
        #expect(model.modules.first?.templateText == "Doc {text}")
        #expect(model.session?.entry(item.id)?.currentName == "Doc New.txt")
    }

    @Test func savesTheAddOnsPatternUnderAName() async throws {
        _ = addFile("scan.txt")
        let model = await model(host())
        await model.setTemplate(Self.free, to: "Mine {text}")
        #expect(model.savePattern(of: Self.free, as: "Mine") == nil)
        #expect(model.savedPatternChoices(for: Self.free).last?.pattern.text == "Mine {text}")
        #expect(model.savePattern(of: Self.free, as: " ") == .emptyName)
    }
}
