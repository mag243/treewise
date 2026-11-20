import Foundation
import Testing
import TreewiseCore

/// The saved patterns as parts: each pattern an element, and the default (ADR 0144).
@Suite struct SavedPatternsPartsTests {
    private static let english = Locale(identifier: "en")

    @Test func readsBackFromItsParts() {
        var list = SavedPatterns.examples(locale: Self.english)
        list.makeDefault(list.patterns[2].id)
        list.move(fromOffsets: [0], toOffset: 3)
        #expect(SavedPatterns(syncElements: list.syncElements, locale: Self.english) == list)
    }

    @Test func twoDevicesChangingDifferentPatternsKeepBoth() {
        let base = SavedPatterns.examples(locale: Self.english)
        var mac = base
        var ipad = base
        mac.change(base.patterns[0].id, to: "{date} mac")
        ipad.change(base.patterns[1].id, to: "{date} ipad")
        var merged = base.syncElements
        for (element, parts) in mac.syncElements where parts != base.syncElements[element] {
            merged[element] = parts
        }
        for (element, parts) in ipad.syncElements where parts != base.syncElements[element] {
            merged[element] = parts
        }
        let list = SavedPatterns(syncElements: merged, locale: Self.english)
        #expect(Array(list.patterns.map(\.text).prefix(2)) == ["{date} mac", "{date} ipad"])
    }

    @Test func aDefaultThatIsGoneFallsToTheFirst() {
        let list = SavedPatterns.examples(locale: Self.english)
        var elements = list.syncElements
        elements[.patternList] = ["default": .string("gone")]
        #expect(
            SavedPatterns(syncElements: elements, locale: Self.english).defaultPattern
                == list.patterns[0])
    }

    @Test func noPatternsLeftGivesTheExamples() {
        let list = SavedPatterns(syncElements: [:], locale: Self.english)
        #expect(list.isExamples(locale: Self.english))
    }

    @Test func aPatternsTextKeepsItsVersion() {
        var list = SavedPatterns.examples(locale: Self.english)
        list.change(list.patterns[0].id, to: "{date}")
        let back = SavedPatterns(syncElements: list.syncElements, locale: Self.english)
        #expect(back.patterns[0].version == 2)
    }
}
