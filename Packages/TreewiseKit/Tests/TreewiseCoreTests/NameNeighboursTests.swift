import Testing
import TreewiseCore

/// The names around a new name, as a folder would sort them (ADR 0057).
@Suite struct NameNeighboursTests {
    @Test func marksTheNameAtItsSortedPlace() {
        let around = NameNeighbours.around(
            "b.pdf", among: ["a.pdf", "c.pdf"], reach: 2)
        #expect(
            around == [
                .init(name: "a.pdf", isNew: false), .init(name: "b.pdf", isNew: true),
                .init(name: "c.pdf", isNew: false),
            ])
    }

    @Test func showsOnlyItsReachOnEachSide() {
        let others = ["1", "2", "3", "5", "6", "7"].map { "\($0).pdf" }
        let around = NameNeighbours.around("4.pdf", among: others, reach: 1)
        #expect(around.map(\.name) == ["3.pdf", "4.pdf", "5.pdf"])
    }

    @Test func sortsNumbersAsAFolderDoes() {
        let around = NameNeighbours.around("9.pdf", among: ["10.pdf", "8.pdf"], reach: 1)
        #expect(around.map(\.name) == ["8.pdf", "9.pdf", "10.pdf"])
    }

    @Test func worksAtTheEdges() {
        #expect(NameNeighbours.around("a", among: ["b"], reach: 2).map(\.name) == ["a", "b"])
        #expect(NameNeighbours.around("a", among: [], reach: 2).map(\.name) == ["a"])
    }
}
