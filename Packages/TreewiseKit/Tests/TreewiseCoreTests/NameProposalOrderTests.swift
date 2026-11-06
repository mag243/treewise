import Testing
import TreewiseCore

/// What a new order of the modules does to the rows (ADR 0065).
@Suite struct NameProposalOrderTests {
    private static let item: FileItem.ID = "/f/scan.pdf"

    private func session() -> NameProposalSession {
        var session = NameProposalSession(
            items: [.init(id: Self.item, folder: "/f", originalName: "scan.pdf", kind: .file)],
            moduleOrder: ["free", "paid"])
        session.add(
            [
                NameProposal(name: "Free", moduleID: "free"),
                NameProposal(name: "Paid", moduleID: "paid"),
            ],
            to: Self.item)
        return session
    }

    @Test func aWaitingRowTakesTheFirstOptionOfTheNewOrder() {
        var session = session()
        session.reorderModules(["paid", "free"])
        #expect(session.entry(Self.item)?.currentName == "Paid.pdf")
        #expect(session.entry(Self.item)?.proposals.map(\.name) == ["Paid.pdf", "Free.pdf"])
    }

    @Test func anApprovedRowKeepsItsName() {
        var session = session()
        session.approve(Self.item)
        session.reorderModules(["paid", "free"])
        #expect(session.entry(Self.item)?.currentName == "Free.pdf")
        #expect(session.entry(Self.item)?.state == .approved)
    }

    @Test func theUsersOwnNameStays() {
        var session = session()
        session.edit(Self.item, to: "Mine.pdf")
        session.reorderModules(["paid", "free"])
        #expect(session.entry(Self.item)?.currentName == "Mine.pdf")
    }
}
