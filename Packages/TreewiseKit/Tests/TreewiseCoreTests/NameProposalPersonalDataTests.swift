import Testing
import TreewiseCore

/// Personal data in a row's name (ADR 0060).
@Suite struct NameProposalPersonalDataTests {
    private static let item: FileItem.ID = "/f/scan.pdf"

    private func session(proposing name: String) -> NameProposalSession {
        var session = NameProposalSession(
            items: [.init(id: Self.item, folder: "/f", originalName: "scan.pdf", kind: .file)],
            moduleOrder: ["first"])
        session.add([NameProposal(name: name, moduleID: "first")], to: Self.item)
        return session
    }

    @Test func findsPersonalDataInAProposal() {
        let entry = session(proposing: "Invoice jan@example.com").entry(Self.item)
        #expect(entry?.personalData == [.emailAddress])
    }

    @Test func findsNothingInAnOrdinaryProposal() {
        #expect(session(proposing: "Invoice F26009").entry(Self.item)?.personalData == [])
    }

    @Test func leavesANameTheUserTypedAlone() {
        var session = session(proposing: "Invoice F26009")
        session.edit(Self.item, to: "Call 06-12345678.pdf")
        #expect(session.entry(Self.item)?.personalData == [])
    }
}
