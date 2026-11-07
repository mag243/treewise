import Foundation
import Testing
import TreewiseCore

/// A folder keeps the saved pattern it uses and is offered a newer version (ADR 0068).
@Suite struct FolderSettingsSavedPatternTests {
    private static let module = "m"
    private static let usable: @Sendable (String, String) -> Bool = { _, _ in true }
    private static let first = SavedPattern(id: "p", name: "Doc", text: "Doc {text}")
    private static let second = SavedPattern(
        id: "p", name: "Doc", text: "Doc {date} {text}", version: 2)

    private func picked() -> FolderSettings {
        var settings = FolderSettings.new(defaultModuleID: Self.module)
        settings.use(Self.first, for: Self.module)
        return settings
    }

    @Test func pickingASavedPatternKeepsItsTextAndVersion() {
        let settings = picked()
        #expect(settings.templates[Self.module] == "Doc {text}")
        #expect(settings.savedPatternLinks[Self.module] == .init(id: "p", version: 1))
    }

    @Test func aNewerVersionIsOfferedAndTheTextStays() {
        let settings = picked()
        #expect(settings.newerVersion(for: Self.module, in: [Self.second]) == Self.second)
        #expect(settings.templates[Self.module] == "Doc {text}")
    }

    @Test func theSameVersionIsNotOffered() {
        #expect(picked().newerVersion(for: Self.module, in: [Self.first]) == nil)
    }

    @Test func takingTheNewerVersionUsesIt() {
        var settings = picked()
        settings.use(Self.second, for: Self.module)
        #expect(settings.templates[Self.module] == "Doc {date} {text}")
        #expect(settings.newerVersion(for: Self.module, in: [Self.second]) == nil)
    }

    @Test func aSkippedVersionIsNotOfferedAgainButTheNextIs() {
        var settings = picked()
        settings.skip(version: 2, for: Self.module)
        #expect(settings.newerVersion(for: Self.module, in: [Self.second]) == nil)
        var third = Self.second
        third.version = 3
        #expect(settings.newerVersion(for: Self.module, in: [third]) == third)
        #expect(settings.templates[Self.module] == "Doc {text}")
    }

    @Test func aChangedFolderIsOfferedNothing() {
        var settings = picked()
        settings.changeTemplate("Mine {text}", for: Self.module, savedText: "Doc {text}")
        #expect(settings.newerVersion(for: Self.module, in: [Self.second]) == nil)
        #expect(settings.savedPatternLinks[Self.module]?.isChanged == true)
    }

    @Test func changingBackToTheSavedTextCountsAsUnchanged() {
        var settings = picked()
        settings.changeTemplate("Mine {text}", for: Self.module, savedText: "Doc {text}")
        settings.changeTemplate("Doc {text}", for: Self.module, savedText: "Doc {text}")
        #expect(settings.savedPatternLinks[Self.module]?.isChanged == false)
    }

    @Test func aRemovedSavedPatternLeavesTheCopy() {
        var settings = picked()
        settings.dropLinks(notIn: [], usable: Self.usable)
        #expect(settings.templates[Self.module] == "Doc {text}")
        #expect(settings.savedPatternLinks[Self.module] == nil)
    }

    @Test func aSavedPatternTheAddOnCannotUseLeavesTheCopy() {
        var settings = picked()
        settings.dropLinks(notIn: [Self.first]) { _, text in !text.contains("Doc") }
        #expect(settings.templates[Self.module] == "Doc {text}")
        #expect(settings.savedPatternLinks[Self.module] == nil)
    }

    @Test func unlinkingEndsTheLink() {
        var settings = picked()
        settings.unlinkSavedPattern(for: Self.module)
        #expect(settings.savedPatternLinks[Self.module] == nil)
        #expect(settings.templates[Self.module] == "Doc {text}")
    }

    @Test func theLinkGoesToTheModuleThatReplacesIt() {
        var settings = picked()
        settings.handOver(from: Self.module, to: "advanced")
        #expect(settings.savedPatternLinks["advanced"] == .init(id: "p", version: 1))
        #expect(settings.savedPatternLinks[Self.module] == nil)
    }

    @Test func theLinkIsStoredAndReadBack() throws {
        var settings = picked()
        settings.skip(version: 2, for: Self.module)
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data) == settings)
    }

    @Test func settingsStoredBeforeLinksExistedHaveNone() throws {
        let data = Data(#"{"enabledModules":["m"],"templates":{"m":"Doc {text}"}}"#.utf8)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data).savedPatternLinks.isEmpty)
    }
}
