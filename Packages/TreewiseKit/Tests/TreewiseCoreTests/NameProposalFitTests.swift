import Testing
import TreewiseCore

/// A name that fits a template during a review: its own name stays the choice, with the
/// proposals as options behind it (ADR 0057, 0138).
@Suite struct NameProposalFitTests {
    private static let item: FileItem.ID = "/f/scan.pdf"

    private func newSession() -> NameProposalSession {
        NameProposalSession(
            items: [.init(id: Self.item, folder: "/f", originalName: "scan.pdf", kind: .file)],
            moduleOrder: ["first", "second"])
    }

    private func proposal(_ name: String) -> NameProposal {
        NameProposal(name: name, moduleID: "first")
    }

    private func session(with names: String...) -> NameProposalSession {
        var result = newSession()
        result.add(names.map { proposal($0) }, to: Self.item)
        return result
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

    /// A name that fits keeps itself as the choice, with the proposals behind it (ADR 0138).
    @Test func aFittingFileWithAProposalRestsOnItsOwnName() {
        var session = session(with: "A")
        session.setFit(Self.item, moduleIDs: ["first"])
        #expect(session.entry(Self.item)?.restsFitting == true)
        #expect(session.entry(Self.item)?.position == .init(index: 0, count: 2))
        #expect(session.approve(Self.item) == .noName)
    }

    @Test func proposalsArrivingForAFittingFileLeaveItsOwnNameChosen() {
        var session = newSession()
        session.setFit(Self.item, moduleIDs: ["first"])
        session.add([proposal("A"), proposal("B")], to: Self.item)
        #expect(session.entry(Self.item)?.restsFitting == true)
        #expect(session.entry(Self.item)?.currentName == nil)
    }

    @Test func aFittingFileStepsToAProposalAndBack() {
        var session = newSession()
        session.setFit(Self.item, moduleIDs: ["first"])
        session.add([proposal("A")], to: Self.item)
        session.step(Self.item, by: .next)
        #expect(session.entry(Self.item)?.currentName == "A.pdf")
        #expect(session.entry(Self.item)?.restsFitting == false)
        #expect(session.approve(Self.item) == nil)
        session.step(Self.item, by: .next)
        #expect(session.entry(Self.item)?.restsFitting == true)
    }

    @Test func approveAllLeavesAFittingFileAsItIs() {
        var session = newSession()
        session.setFit(Self.item, moduleIDs: ["first"])
        session.add([proposal("A")], to: Self.item)
        session.approveAll()
        #expect(session.approvedRenames.isEmpty)
    }

    @Test func aFileThatStopsFittingTakesItsBestProposal() {
        var session = session(with: "A")
        session.setFit(Self.item, moduleIDs: ["first"])
        session.setFit(Self.item, moduleIDs: [])
        #expect(session.entry(Self.item)?.currentName == "A.pdf")
    }

    @Test func aProposalTheUserSteppedToStaysWhenTheFileIsFoundToFit() {
        var session = newSession()
        session.add([proposal("A"), proposal("B")], to: Self.item)
        session.step(Self.item, by: .next)
        session.setFit(Self.item, moduleIDs: ["first"])
        #expect(session.entry(Self.item)?.currentName == "B.pdf")
    }
}
