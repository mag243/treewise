import Foundation
import Testing
import TreewiseCore

/// A folder follows the saved pattern it uses unchanged (ADR 0068).
@Suite struct FolderSettingsSavedPatternTests {
    private static let module = "m"
    private static let usable: @Sendable (String, String) -> Bool = { _, _ in true }

    private func picked(_ text: String = "Doc {text}") -> FolderSettings {
        var settings = FolderSettings.new(defaultModuleID: Self.module)
        settings.use(savedPattern: "p", text: text, for: Self.module)
        return settings
    }

    @Test func pickingASavedPatternKeepsItsTextAndFollowsIt() {
        let settings = picked()
        #expect(settings.templates[Self.module] == "Doc {text}")
        #expect(settings.savedPatternLinks[Self.module] == .init(id: "p", isChanged: false))
    }

    @Test func anUnchangedFolderTakesTheSavedPatternsNewText() {
        var settings = picked()
        settings.follow(savedPatterns: ["p": "Doc {date} {text}"], usable: Self.usable)
        #expect(settings.templates[Self.module] == "Doc {date} {text}")
    }

    @Test func aChangedFolderKeepsItsOwnText() {
        var settings = picked()
        settings.changeTemplate("Mine {text}", for: Self.module, savedText: "Doc {text}")
        settings.follow(savedPatterns: ["p": "Doc {date} {text}"], usable: Self.usable)
        #expect(settings.templates[Self.module] == "Mine {text}")
        #expect(settings.savedPatternLinks[Self.module]?.isChanged == true)
    }

    @Test func changingBackToTheSavedTextFollowsAgain() {
        var settings = picked()
        settings.changeTemplate("Mine {text}", for: Self.module, savedText: "Doc {text}")
        settings.changeTemplate("Doc {text}", for: Self.module, savedText: "Doc {text}")
        #expect(settings.savedPatternLinks[Self.module]?.isChanged == false)
    }

    @Test func aRemovedSavedPatternLeavesTheCopyAndTheLink() {
        var settings = picked()
        settings.follow(savedPatterns: [:], usable: Self.usable)
        #expect(settings.templates[Self.module] == "Doc {text}")
        #expect(settings.savedPatternLinks[Self.module] == nil)
    }

    @Test func aSavedPatternTheAddOnCannotUseLeavesTheCopy() {
        var settings = picked()
        settings.follow(
            savedPatterns: ["p": "Co {company}"], usable: { _, text in !text.contains("company") })
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
        #expect(settings.savedPatternLinks["advanced"] == .init(id: "p", isChanged: false))
        #expect(settings.savedPatternLinks[Self.module] == nil)
    }

    @Test func theLinkIsStoredAndReadBack() throws {
        let settings = picked()
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data) == settings)
    }

    @Test func settingsStoredBeforeLinksExistedHaveNone() throws {
        let data = Data(#"{"enabledModules":["m"],"templates":{"m":"Doc {text}"}}"#.utf8)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data).savedPatternLinks.isEmpty)
    }
}
