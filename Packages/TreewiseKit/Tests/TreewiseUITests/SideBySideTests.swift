import Foundation
import Testing
import TreewiseUI

/// Where Window Beside and Tile put two windows (ADR 0037).
@Suite struct SideBySideTests {
    private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

    @Test func givesEachWindowHalfOfAWideScreen() {
        let frames = SideBySide.frames(in: screen, minimumWidth: 620)
        #expect(frames.left == CGRect(x: 0, y: 25, width: 720, height: 875))
        #expect(frames.right == CGRect(x: 720, y: 25, width: 720, height: 875))
    }

    @Test func putsTheWindowsAgainstTheEdgesOfANarrowScreen() {
        let narrow = CGRect(x: 0, y: 25, width: 1024, height: 743)
        let frames = SideBySide.frames(in: narrow, minimumWidth: 620)
        #expect(frames.left == CGRect(x: 0, y: 25, width: 620, height: 743))
        #expect(frames.right == CGRect(x: 404, y: 25, width: 620, height: 743))
    }

    @Test func givesBothWindowsTheWholeOfAScreenNarrowerThanOne() {
        let tiny = CGRect(x: 100, y: 0, width: 600, height: 400)
        let frames = SideBySide.frames(in: tiny, minimumWidth: 620)
        #expect(frames.left == tiny)
        #expect(frames.right == tiny)
    }

    @Test func keepsTheScreenOrigin() {
        let second = CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        let frames = SideBySide.frames(in: second, minimumWidth: 620)
        #expect(frames.left.minX == 1440)
        #expect(frames.right.maxX == 3360)
    }
}
