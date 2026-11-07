import Foundation
import Testing
import TreewiseCore

/// The user's named patterns, one of them the default (ADR 0068).
@Suite struct SavedPatternsTests {
    private let examples = SavedPatterns.examples(locale: Locale(identifier: "en"))

    @Test func startsWithTheExamplesAndADateAndTextAsDefault() {
        #expect(
            examples.patterns.map(\.text) == [
                "{date:yyyy.MM.dd} {text}", "{date:yyyy-MM-dd} {text}", "{folder} {seq}",
                "{date:yyyy.MM.dd} {folder} - {text}",
            ])
        #expect(examples.defaultPattern.text == "{date:yyyy.MM.dd} {text}")
    }

    @Test func aSingleDefaultBecomesTheListsDefault() {
        let patterns = SavedPatterns(keeping: "{text} - {seq}", locale: Locale(identifier: "en"))
        #expect(patterns.defaultPattern.text == "{text} - {seq}")
        #expect(patterns.patterns.count == examples.patterns.count + 1)
    }

    @Test func aSingleDefaultThatIsAnExampleMakesThatExampleTheDefault() {
        let patterns = SavedPatterns(keeping: "{folder} {seq}", locale: Locale(identifier: "en"))
        #expect(patterns.defaultPattern.text == "{folder} {seq}")
        #expect(patterns.patterns.count == examples.patterns.count)
    }

    @Test func savesAPatternWithoutSpacesAtItsEnds() throws {
        var patterns = examples
        let id = try patterns.save(name: " Tax ", text: " Tax - {text} ").get()
        #expect(patterns.patterns.last == SavedPattern(id: id, name: "Tax", text: "Tax - {text}"))
    }

    @Test func aPatternNeedsAName() {
        var patterns = examples
        #expect(patterns.save(name: "  ", text: "{text}") == .failure(.emptyName))
        #expect(patterns.patterns == examples.patterns)
    }

    @Test func renamesAPattern() {
        var patterns = examples
        let id = patterns.patterns[1].id
        #expect(patterns.rename(id, to: "Dashes") == nil)
        #expect(patterns.patterns[1].name == "Dashes")
        #expect(patterns.rename(id, to: "") == .emptyName)
    }

    @Test func changesTheTextOfAPattern() {
        var patterns = examples
        let id = patterns.patterns[2].id
        patterns.change(id, to: " {folder} - {seq} ")
        #expect(patterns.patterns[2].text == "{folder} - {seq}")
    }

    @Test func changingTheTextMakesANewVersion() {
        var patterns = examples
        let id = patterns.patterns[2].id
        #expect(patterns.patterns[2].version == 1)
        patterns.change(id, to: "{folder} - {seq}")
        #expect(patterns.patterns[2].version == 2)
        patterns.change(id, to: "{folder} - {seq} ")
        #expect(patterns.patterns[2].version == 2, "the same text makes no version")
    }

    @Test func aPatternStoredBeforeVersionsIsTheFirst() throws {
        let data = Data(#"{"id":"p","name":"Doc","text":"Doc {text}"}"#.utf8)
        #expect(try JSONDecoder().decode(SavedPattern.self, from: data).version == 1)
    }

    @Test func removesAPattern() {
        var patterns = examples
        let id = patterns.patterns[1].id
        #expect(patterns.remove(id) == nil)
        #expect(!patterns.patterns.contains { $0.id == id })
    }

    @Test func removingTheDefaultMakesTheFirstTheDefault() {
        var patterns = examples
        patterns.remove(patterns.defaultPattern.id)
        #expect(patterns.defaultPattern == patterns.patterns[0])
    }

    @Test func keepsTheLastPattern() {
        var patterns = examples
        while patterns.patterns.count > 1 { patterns.remove(patterns.patterns[0].id) }
        #expect(patterns.remove(patterns.patterns[0].id) == .lastPattern)
        #expect(patterns.patterns.count == 1)
    }

    @Test func choosesTheDefault() {
        var patterns = examples
        patterns.makeDefault(patterns.patterns[2].id)
        #expect(patterns.defaultPattern.text == "{folder} {seq}")
    }

    @Test func movesAPattern() {
        var patterns = examples
        let moved = patterns.patterns[3].id
        patterns.move(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(patterns.patterns.first?.id == moved)
    }

    @Test func roundTripsAsJSON() throws {
        let data = try JSONEncoder().encode(examples)
        #expect(try JSONDecoder().decode(SavedPatterns.self, from: data) == examples)
    }

    @Test func anEmptyStoredListIsNoList() {
        let json = Data(#"{"patterns":[],"defaultID":"x"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SavedPatterns.self, from: json)
        }
    }
}
