import Testing
import TreewiseCore

/// Reviewing proposed names: stepping, later arrivals, edits and approval (ADR 0057).
@Suite struct NameProposalSessionTests {
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

    @Test func startsWithoutAName() {
        let entry = newSession().entry(Self.item)
        #expect(entry?.currentName == nil)
        #expect(entry?.state == .pending)
    }

    @Test func choosesTheFirstProposalOfTheFirstModule() {
        var session = newSession()
        session.add(
            [proposal("Late", from: "second"), proposal("Early", from: "first")], to: Self.item)
        #expect(session.entry(Self.item)?.currentName == "Early.pdf")
    }

    @Test func ordersByModuleAndThenByEachModulesRanking() {
        var session = newSession()
        session.add(
            [
                proposal("C", from: "second"), proposal("A"), proposal("D", from: "second"),
                proposal("B"),
            ],
            to: Self.item)
        #expect(names(session) == ["A.pdf", "B.pdf", "C.pdf", "D.pdf"])
    }

    @Test func dropsInvalidProposalsAndKeepsTheRest() {
        var session = newSession()
        session.add([proposal("a:b"), proposal("Good")], to: Self.item)
        #expect(names(session) == ["Good.pdf"])
    }

    @Test func dropsAProposalThatChangesNothing() {
        #expect(session(with: "scan").entry(Self.item)?.proposals.isEmpty == true)
    }

    @Test func keepsACaseOnlyChange() {
        #expect(session(with: "Scan").entry(Self.item)?.currentName == "Scan.pdf")
    }

    @Test func stepsForwardAndWrapsAround() {
        var session = session(with: "A", "B")
        session.step(Self.item, by: .next)
        #expect(session.entry(Self.item)?.currentName == "B.pdf")
        session.step(Self.item, by: .next)
        #expect(session.entry(Self.item)?.currentName == "A.pdf")
    }

    @Test func stepsBackAndWrapsAround() {
        var session = session(with: "A", "B")
        session.step(Self.item, by: .previous)
        #expect(session.entry(Self.item)?.currentName == "B.pdf")
    }

    @Test func steppingWithoutProposalsDoesNothing() {
        var session = newSession()
        session.step(Self.item, by: .next)
        #expect(session.entry(Self.item)?.currentName == nil)
    }

    @Test func reportsThePositionAmongTheOptions() {
        var session = session(with: "A", "B")
        session.step(Self.item, by: .next)
        #expect(session.entry(Self.item)?.position == .init(index: 1, count: 2))
    }

    @Test func aLaterProposalDoesNotMoveTheChoice() {
        var session = session(with: "A", "B")
        session.step(Self.item, by: .next)
        session.add([proposal("Before", from: "first")], to: Self.item)
        #expect(session.entry(Self.item)?.currentName == "B.pdf")
    }

    @Test func aLaterProposalDoesNotReplaceAnEdit() {
        var session = session(with: "A")
        session.edit(Self.item, to: "Mine.pdf")
        session.add([proposal("Better")], to: Self.item)
        #expect(session.entry(Self.item)?.currentName == "Mine.pdf")
    }

    @Test func anEditStaysReachableWhileStepping() {
        var session = session(with: "A")
        session.edit(Self.item, to: "Mine.pdf")
        session.step(Self.item, by: .next)
        #expect(session.entry(Self.item)?.currentName == "A.pdf")
        session.step(Self.item, by: .next)
        #expect(session.entry(Self.item)?.currentName == "Mine.pdf")
    }

    @Test func discardingAnEditReturnsToTheBestProposal() {
        var session = session(with: "A")
        session.edit(Self.item, to: "Mine.pdf")
        session.discardEdit(Self.item)
        #expect(session.entry(Self.item)?.currentName == "A.pdf")
        #expect(session.entry(Self.item)?.position == .init(index: 0, count: 1))
    }

    @Test func approvesAValidName() {
        var session = session(with: "A")
        #expect(session.approve(Self.item) == nil)
        #expect(session.entry(Self.item)?.state == .approved)
    }

    @Test func refusesToApproveWithoutAName() {
        var session = newSession()
        #expect(session.approve(Self.item) == .noName)
        #expect(session.entry(Self.item)?.state == .pending)
    }

    @Test func refusesToApproveAnInvalidEdit() {
        var session = session(with: "A")
        session.edit(Self.item, to: "a:b")
        #expect(session.approve(Self.item) == .containsPathSeparator)
    }

    @Test func refusesToApproveAnUnchangedName() {
        var session = session(with: "A")
        session.edit(Self.item, to: "scan.pdf")
        #expect(session.approve(Self.item) == .unchanged)
    }

    @Test(arguments: [true, false])
    func changingTheNameNeedsApprovalAgain(_ edits: Bool) {
        var session = session(with: "A", "B")
        session.approve(Self.item)
        if edits {
            session.edit(Self.item, to: "Mine.pdf")
        } else {
            session.step(Self.item, by: .next)
        }
        #expect(session.entry(Self.item)?.state == .pending)
    }

    @Test func aLaterProposalKeepsAnApproval() {
        var session = session(with: "A")
        session.approve(Self.item)
        session.add([proposal("Better")], to: Self.item)
        #expect(session.entry(Self.item)?.state == .approved)
        #expect(session.entry(Self.item)?.currentName == "A.pdf")
    }

    @Test func skippingLeavesTheItemOutOfTheRenames() {
        var session = session(with: "A")
        session.approve(Self.item)
        session.skip(Self.item)
        #expect(session.entry(Self.item)?.state == .skipped)
        #expect(session.approvedRenames.isEmpty)
    }

    @Test func takesBackADecision() {
        var session = session(with: "A")
        session.approve(Self.item)
        session.undecide(Self.item)
        #expect(session.entry(Self.item)?.state == .pending)
        session.skip(Self.item)
        session.undecide(Self.item)
        #expect(session.entry(Self.item)?.state == .pending)
    }

    @Test func approveAllTakesOnlyPendingItemsWithAValidName() {
        var session = NameProposalSession(
            items: ["a", "b", "c", "d"].map {
                .init(
                    id: FileItem.ID("/f/\($0)"), folder: "/f", originalName: "\($0).pdf",
                    kind: .file)
            },
            moduleOrder: ["first"])
        session.add([proposal("A1")], to: "/f/a")
        session.add([proposal("C1")], to: "/f/c")
        session.skip("/f/c")
        session.edit("/f/d", to: "x:y")
        session.approveAll(dateInFileIsReliable: false)
        #expect(session.entry("/f/a")?.state == .approved)
        #expect(session.entry("/f/b")?.state == .pending)
        #expect(session.entry("/f/c")?.state == .skipped)
        #expect(session.entry("/f/d")?.state == .pending)
    }

    @Test func approvedRenamesFollowTheItemsOrder() {
        var session = NameProposalSession(
            items: ["a", "b"].map {
                .init(
                    id: FileItem.ID("/f/\($0)"), folder: "/f", originalName: "\($0).pdf",
                    kind: .file)
            },
            moduleOrder: ["first"])
        session.add([proposal("B1")], to: "/f/b")
        session.add([proposal("A1")], to: "/f/a")
        session.approveAll(dateInFileIsReliable: false)
        #expect(
            session.approvedRenames == [
                BatchRename(item: "/f/a", folder: "/f", from: "a.pdf", to: "A1.pdf"),
                BatchRename(item: "/f/b", folder: "/f", from: "b.pdf", to: "B1.pdf"),
            ])
    }

    @Test func ignoresAnUnknownItem() {
        var session = newSession()
        session.add([proposal("A")], to: "/gone")
        session.step("/gone", by: .next)
        #expect(session.approve("/gone") == .noName)
        #expect(session.entry("/gone") == nil)
    }
}
