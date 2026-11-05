import Testing
import TreewiseCore

/// How proposals and edits merge, change and fit during a review (ADR 0057).
@Suite struct NameProposalMergingTests {
    private static let item: FileItem.ID = "/f/scan.pdf"

    private func newSession(modules: [String] = ["first", "second"]) -> NameProposalSession {
        NameProposalSession(
            items: [.init(id: Self.item, folder: "/f", originalName: "scan.pdf", kind: .file)],
            moduleOrder: modules)
    }

    private func proposal(_ name: String, from module: String = "first") -> NameProposal {
        NameProposal(name: name, moduleID: module)
    }

    private func session(with names: String...) -> NameProposalSession {
        var result = newSession()
        result.add(names.map { proposal($0) }, to: Self.item)
        return result
    }

    private func names(_ session: NameProposalSession) -> [String]? {
        session.entry(Self.item)?.proposals.map(\.name)
    }

    @Test func twoModulesWithOneNameGiveOneOptionNamingBoth() {
        var session = newSession()
        session.add([proposal("Same"), proposal("Same", from: "second")], to: Self.item)
        #expect(session.entry(Self.item)?.proposals.map(\.moduleIDs) == [["first", "second"]])
    }

    @Test func aSharedOptionStaysAtTheFirstModulesPlace() {
        var session = newSession()
        session.add(
            [proposal("Other"), proposal("Same"), proposal("Same", from: "second")], to: Self.item)
        #expect(names(session) == ["Other.pdf", "Same.pdf"])
    }

    @Test func agreeingDoesNotMoveAnOptionUp() {
        var session = newSession()
        session.add(
            [
                proposal("First"), proposal("Second", from: "second"),
                proposal("Third", from: "second"),
            ],
            to: Self.item)
        session.add([proposal("Third")], to: Self.item)
        #expect(session.entry(Self.item)?.proposals.first?.name == "First.pdf")
    }

    @Test func namesDifferingInCaseAreOneOptionInTheFirstModulesSpelling() {
        var session = newSession()
        session.add([proposal("same", from: "second")], to: Self.item)
        session.add([proposal("Same")], to: Self.item)
        #expect(names(session) == ["Same.pdf"])
        #expect(session.entry(Self.item)?.currentName == "Same.pdf")
    }

    @Test func anEditEqualToAProposalStaysWhileTyping() {
        var session = session(with: "A")
        session.edit(Self.item, to: "A.pdf")
        #expect(session.entry(Self.item)?.edit == "A.pdf")
        #expect(session.entry(Self.item)?.position == .init(index: 1, count: 2))
    }

    @Test func anEditEqualToAProposalMergesWhenTheFieldIsLeft() {
        var session = session(with: "A", "B")
        session.edit(Self.item, to: "B.pdf")
        session.finishEditing(Self.item)
        #expect(session.entry(Self.item)?.edit == nil)
        #expect(session.entry(Self.item)?.position == .init(index: 1, count: 2))
        #expect(session.entry(Self.item)?.currentName == "B.pdf")
    }

    @Test func anEditDifferingInCaseStaysTheUsers() {
        var session = session(with: "A")
        session.edit(Self.item, to: "a.pdf")
        session.finishEditing(Self.item)
        #expect(session.entry(Self.item)?.edit == "a.pdf")
    }

    @Test(arguments: ["", "   "])
    func anEmptyEditGoesAwayWhenTheFieldIsLeft(_ text: String) {
        var session = session(with: "A", "B")
        session.step(Self.item, by: .next)
        session.edit(Self.item, to: text)
        session.finishEditing(Self.item)
        #expect(session.entry(Self.item)?.edit == nil)
        #expect(session.entry(Self.item)?.currentName == "A.pdf")
    }

    @Test func aLaterEqualProposalMergesAndKeepsAnApproval() {
        var session = session(with: "A")
        session.edit(Self.item, to: "Mine.pdf")
        session.approve(Self.item)
        session.add([proposal("Mine")], to: Self.item)
        let entry = session.entry(Self.item)
        #expect(entry?.edit == nil)
        #expect(entry?.state == .approved)
        #expect(entry?.currentName == "Mine.pdf")
    }

    @Test func replacingAModulesProposalsKeepsTheOthers() {
        var session = newSession()
        session.add([proposal("A"), proposal("B", from: "second")], to: Self.item)
        session.replaceProposals([proposal("New")], from: "first", for: Self.item)
        #expect(names(session) == ["New.pdf", "B.pdf"])
    }

    @Test func replacingFallsBackToTheBestWhenTheChoiceIsGone() {
        var session = session(with: "A")
        session.replaceProposals([proposal("New")], from: "first", for: Self.item)
        #expect(session.entry(Self.item)?.currentName == "New.pdf")
    }

    @Test func replacingKeepsAChoiceThatIsStillThere() {
        var session = session(with: "A", "B")
        session.step(Self.item, by: .next)
        session.replaceProposals([proposal("Z"), proposal("B")], from: "first", for: Self.item)
        #expect(session.entry(Self.item)?.currentName == "B.pdf")
    }

    @Test func replacingKeepsAnApprovedNameAsTheUsersOwn() {
        var session = session(with: "A")
        session.approve(Self.item)
        session.replaceProposals([], from: "first", for: Self.item)
        let entry = session.entry(Self.item)
        #expect(entry?.state == .approved)
        #expect(entry?.currentName == "A.pdf")
        #expect(entry?.edit == "A.pdf")
    }

    @Test func aSharedOptionLosesOnlyTheReplacedModule() {
        var session = newSession()
        session.add([proposal("Same"), proposal("Same", from: "second")], to: Self.item)
        session.replaceProposals([], from: "first", for: Self.item)
        #expect(session.entry(Self.item)?.proposals.map(\.moduleIDs) == [["second"]])
    }

    @Test func recordsWhichModulesAFileFits() {
        var session = session(with: "A")
        session.setFit(Self.item, moduleIDs: ["second", "first"])
        #expect(session.entry(Self.item)?.fittingModuleIDs == ["first", "second"])
    }

    @Test func aFittingFileWithoutOptionsRests() {
        var session = newSession()
        session.setFit(Self.item, moduleIDs: ["first"])
        #expect(session.entry(Self.item)?.restsFitting == true)
        #expect(session.approve(Self.item) == .noName)
    }

    @Test func aFittingFileWithAProposalDoesNotRest() {
        var session = session(with: "A")
        session.setFit(Self.item, moduleIDs: ["first"])
        #expect(session.entry(Self.item)?.restsFitting == false)
    }

    @Test func anOutOfScopeFileCannotBeApproved() {
        var session = session(with: "A")
        session.setOutOfScope(Self.item, true)
        #expect(session.entry(Self.item)?.isOutOfScope == true)
        #expect(session.approve(Self.item) == .noName)
    }
}
