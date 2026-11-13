import Testing
import TreewiseUI

/// Where a list scrolls to show the card selected (ADR 0092).
@Suite struct RevealScrollTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let cardTop: Double
        let cardHeight: Double
        let visibleTop: Double
        let expected: Double?
        let why: String
        var testDescription: String { why }
    }

    /// A list 300 high over 1000 of cards.
    private static let visibleHeight = 300.0
    private static let contentHeight = 1000.0

    @Test(arguments: [
        Case(cardTop: 50, cardHeight: 100, visibleTop: 0, expected: nil, why: "shows whole"),
        Case(cardTop: 250, cardHeight: 100, visibleTop: 0, expected: 50, why: "below: its foot"),
        Case(cardTop: 100, cardHeight: 80, visibleTop: 200, expected: 100, why: "above: its top"),
        Case(cardTop: 400, cardHeight: 500, visibleTop: 0, expected: 400, why: "taller: its top"),
        Case(
            cardTop: 400, cardHeight: 500, visibleTop: 400, expected: nil, why: "taller, top shown"),
        Case(cardTop: 900, cardHeight: 100, visibleTop: 0, expected: 700, why: "last: to the end"),
    ])
    func showsTheCardWholeOrItsTop(_ row: Case) {
        let top = RevealScroll.top(
            card: row.cardTop..<(row.cardTop + row.cardHeight), visibleTop: row.visibleTop,
            visibleHeight: Self.visibleHeight, contentHeight: Self.contentHeight)
        #expect(top == row.expected)
    }

    @Test func staysAtTheTopWhenTheCardsFit() {
        let top = RevealScroll.top(
            card: 250..<350, visibleTop: 0, visibleHeight: 400, contentHeight: 360)
        #expect(top == nil)
    }
}
