import Testing
import TreewiseCore
import TreewiseUI

/// A folder keeps the saved pattern it uses, is offered a newer version, and can update it
/// (ADR 0068).
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
        #expect(model.newerSavedPattern(for: Self.free) == nil, "it uses the version it made")
    }

    @Test func aFolderKeepsItsPatternAndIsOfferedTheNewerVersion() async throws {
        _ = addFile("scan.txt")
        let first = await model(host())
        let doc = try doc(in: first)
        await first.useSavedPattern(doc.id, for: Self.free)
        savedPatterns.change(doc.id, to: "Doc {text} v2")
        let again = await model(host())
        #expect(again.modules.first?.templateText == "Doc {text}")
        #expect(again.newerSavedPattern(for: Self.free)?.text == "Doc {text} v2")
    }

    @Test func useItTakesTheNewerVersion() async throws {
        let item = addFile("scan.txt")
        let first = await model(host())
        let doc = try doc(in: first)
        await first.useSavedPattern(doc.id, for: Self.free)
        savedPatterns.change(doc.id, to: "Doc {text} v2")
        let again = await model(host())
        await again.useNewerSavedPattern(for: Self.free)
        #expect(again.modules.first?.templateText == "Doc {text} v2")
        #expect(again.session?.entry(item.id)?.currentName == "Doc New v2.txt")
        #expect(again.newerSavedPattern(for: Self.free) == nil)
    }

    @Test func keepMineSkipsThatVersionButNotTheNext() async throws {
        _ = addFile("scan.txt")
        let first = await model(host())
        let doc = try doc(in: first)
        await first.useSavedPattern(doc.id, for: Self.free)
        savedPatterns.change(doc.id, to: "Doc {text} v2")
        let second = await model(host())
        await second.keepPatternInsteadOfNewer(for: Self.free)
        #expect(second.newerSavedPattern(for: Self.free) == nil)
        #expect(second.modules.first?.templateText == "Doc {text}")
        savedPatterns.change(doc.id, to: "Doc {text} v3")
        let third = await model(host())
        #expect(third.newerSavedPattern(for: Self.free)?.text == "Doc {text} v3")
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
        #expect(again.newerSavedPattern(for: Self.free) == nil)
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
        #expect(again.newerSavedPattern(for: Self.free) == nil)
    }

    @Test func aNewerVersionWithTheSameTextIsNotOffered() async throws {
        _ = addFile("scan.txt")
        let first = await model(host())
        let doc = try doc(in: first)
        await first.useSavedPattern(doc.id, for: Self.free)
        savedPatterns.change(doc.id, to: "Doc {text} v2")
        savedPatterns.change(doc.id, to: "Doc {text}")
        let again = await model(host())
        #expect(again.newerSavedPattern(for: Self.free) == nil)
        #expect(again.modules.first?.templateText == "Doc {text}")
    }
}
