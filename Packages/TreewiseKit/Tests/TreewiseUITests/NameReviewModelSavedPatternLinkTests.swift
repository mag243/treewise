import Testing
import TreewiseCore
import TreewiseUI

/// A folder follows the saved pattern it uses unchanged, and can update it (ADR 0068).
extension NameReviewModelTests {
    private func doc(in model: NameReviewModel) throws -> SavedPattern {
        try #require(model.savedPatternChoices(for: Self.free).first { $0.pattern.name == "Doc" })
            .pattern
    }

    @Test func aFolderThatUsesASavedPatternUnchangedOffersNoUpdate() async throws {
        _ = addFile("scan.txt")
        let model = await model(host())
        await model.useSavedPattern(try doc(in: model).id, for: Self.free)
        #expect(model.savedPatternToUpdate(for: Self.free) == nil)
    }

    @Test func aChangedPatternUpdatesTheSavedPatternItWasPickedFrom() async throws {
        _ = addFile("scan.txt")
        let model = await model(host())
        let doc = try doc(in: model)
        await model.useSavedPattern(doc.id, for: Self.free)
        await model.setTemplate(Self.free, to: "Doc {text} v2")
        #expect(model.savedPatternToUpdate(for: Self.free)?.name == "Doc")
        await model.updateSavedPattern(for: Self.free)
        #expect(savedPatterns.list.patterns.first { $0.id == doc.id }?.text == "Doc {text} v2")
        #expect(model.savedPatternToUpdate(for: Self.free) == nil)
    }

    @Test func aFolderFollowsTheSavedPatternItUsesUnchanged() async throws {
        _ = addFile("scan.txt")
        let first = await model(host())
        let doc = try doc(in: first)
        await first.useSavedPattern(doc.id, for: Self.free)
        savedPatterns.change(doc.id, to: "Doc {text} v2")
        let again = await model(host())
        #expect(again.modules.first?.templateText == "Doc {text} v2")
    }

    @Test func aFolderWhosePatternChangedKeepsItsOwn() async throws {
        _ = addFile("scan.txt")
        let first = await model(host())
        let doc = try doc(in: first)
        await first.useSavedPattern(doc.id, for: Self.free)
        await first.setTemplate(Self.free, to: "Mine {text}")
        savedPatterns.change(doc.id, to: "Doc {text} v2")
        let again = await model(host())
        #expect(again.modules.first?.templateText == "Mine {text}")
    }

    @Test func pickingAFoundPatternEndsTheLink() async throws {
        _ = addFile("scan.txt")
        let first = await model(host())
        let doc = try doc(in: first)
        await first.useSavedPattern(doc.id, for: Self.free)
        await first.useFoundPattern("Found {text}", for: Self.free)
        savedPatterns.change(doc.id, to: "Doc {text} v2")
        let again = await model(host())
        #expect(again.modules.first?.templateText == "Found {text}")
        #expect(again.savedPatternToUpdate(for: Self.free) == nil)
    }
}
