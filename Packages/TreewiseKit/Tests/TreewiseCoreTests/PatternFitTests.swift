import Testing
import TreewiseCore

/// When a pattern counts as recognized in a folder, for every module (ADR 0067).
@Suite struct PatternFitTests {
    @Test(arguments: [
        (3, 4, true), (3, 5, true), (6, 10, true), (3, 3, true),
        (2, 3, false), (3, 6, false), (2, 5, false), (0, 0, false),
    ])
    func aPatternIsRecognizedWhenAMajorityOfAtLeastThreeFilesFitIt(
        fits: Int, of files: Int, recognized: Bool
    ) {
        #expect(PatternFit.isRecognized(fits: fits, of: files) == recognized)
    }

    @Test(arguments: [(3, 6, true), (3, 4, true), (2, 4, false), (3, 7, false)])
    func aPatternIsOfferedWhenAtLeastHalfAndThreeFilesFitIt(fits: Int, of files: Int, offered: Bool)
    {
        #expect(PatternFit.isOffered(fits: fits, of: files) == offered)
    }

    @Test(arguments: [(8, 10, true), (4, 4, true), (7, 10, false), (3, 4, false)])
    func aPatternIsClearWhenFourFifthsFitIt(fits: Int, of files: Int, clear: Bool) {
        #expect(PatternFit.isClear(fits: fits, of: files) == clear)
    }
}
