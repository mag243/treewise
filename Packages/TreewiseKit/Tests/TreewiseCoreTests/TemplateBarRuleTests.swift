import Foundation
import Testing

@testable import TreewiseCore

/// When an empty folder offers a template's folders, and from where (ADR 0094, ADR 0097).
@Suite struct TemplateBarRuleTests {
    private static let year = FolderTemplate(
        id: "year", name: "Household Year",
        root: FolderTree(name: "{year}", folders: [FolderTree(name: "Tax")]))
    private static let client = FolderTemplate(
        id: "client", name: "Client",
        root: FolderTree(name: "P-{seq} {text}", folders: [FolderTree(name: "Contract")]))

    private static func ask(
        _ path: String, empty: Bool = true, own: FolderSettings? = nil,
        above: FolderSettings? = nil, mayWork: Bool = true, yearBeforeHasFolders: Bool = false,
        templates: [FolderTemplate] = [year, client]
    ) -> TemplateBarRule.Source? {
        let folder = TemplateBarRule.Folder(
            id: FileItem.ID(path), holdsOnlyHiddenItems: empty, settings: own,
            settingsAbove: above, yearBeforeHasFolders: yearBeforeHasFolders)
        return TemplateBarRule.source(for: folder, addOnMayWork: mayWork, templates: templates)
    }

    private static func settings(_ offer: FolderSettings.NewFolders) -> FolderSettings {
        var settings = FolderSettings(enabledModules: [], templates: [:])
        settings.newFolders = offer
        return settings
    }

    @Test func offersTheFoldersOfTheYearBefore() {
        #expect(
            Self.ask("/v/Household/2027", yearBeforeHasFolders: true)
                == .yearBefore(FileItem.ID("/v/Household/2026")))
    }

    @Test func offersTheOneTemplateRootedAtTheYearWithoutAYearBefore() {
        #expect(Self.ask("/v/Household/2027") == .template(Self.year))
    }

    @Test func offersNoTemplateWhenSeveralAreRootedAtTheYear() {
        let another = FolderTemplate(id: "b", name: "B", root: FolderTree(name: "{year}"))
        #expect(Self.ask("/v/Household/2027", templates: [Self.year, another]) == nil)
    }

    @Test func offersNothingInAFolderWithoutAYearUnlessTheFolderAboveChoseATemplate() {
        #expect(Self.ask("/v/Clients/Acme") == nil)
        #expect(
            Self.ask("/v/Clients/Acme", above: Self.settings(.template(id: "client")))
                == .template(Self.client))
    }

    @Test func aTemplateChosenAboveWinsOverTheYearBefore() {
        let source = Self.ask(
            "/v/Household/2027", above: Self.settings(.template(id: "client")),
            yearBeforeHasFolders: true)
        #expect(source == .template(Self.client))
    }

    @Test func aTemplateThatIsGoneCountsAsAutomatic() {
        let source = Self.ask(
            "/v/Household/2027", above: Self.settings(.template(id: "deleted")),
            yearBeforeHasFolders: true)
        #expect(source == .yearBefore(FileItem.ID("/v/Household/2026")))
    }

    @Test func offersNothingWhereTheFolderAboveSaysNone() {
        let source = Self.ask(
            "/v/Household/2027", above: Self.settings(.none), yearBeforeHasFolders: true)
        #expect(source == nil)
    }

    @Test func offersNothingOnceTheBarIsClosedForTheFolder() {
        var closed = FolderSettings(enabledModules: [], templates: [:])
        closed.templateBarClosed = true
        #expect(Self.ask("/v/Household/2027", own: closed, yearBeforeHasFolders: true) == nil)
    }

    @Test func offersNothingInAFolderThatHoldsSomething() {
        #expect(Self.ask("/v/Household/2027", empty: false, yearBeforeHasFolders: true) == nil)
    }

    @Test func offersNothingWhileTheAddOnMayNotWork() {
        #expect(Self.ask("/v/Household/2027", mayWork: false, yearBeforeHasFolders: true) == nil)
    }

    @Test func aYearDeeperInThePathOffersTheSameFolderAYearBeforeButNoTemplate() {
        #expect(
            Self.ask("/v/Household/2027/Tax", yearBeforeHasFolders: true)
                == .yearBefore(FileItem.ID("/v/Household/2026/Tax")))
        #expect(Self.ask("/v/Household/2027/Tax") == nil)
    }
}

/// What a folder keeps of templates (ADR 0094, ADR 0097), beside what the review keeps.
@Suite struct FolderSettingsTemplatesTests {
    @Test func offersAutomaticallyAndKeepsTheBarOpenUntilToldOtherwise() {
        let settings = FolderSettings(enabledModules: ["m"], templates: [:])
        #expect(settings.newFolders == .automatic)
        #expect(!settings.templateBarClosed)
    }

    @Test func readsSettingsSavedBeforeTemplatesExisted() throws {
        let old = Data(#"{"enabledModules": ["m"], "templates": {}}"#.utf8)
        let settings = try JSONDecoder().decode(FolderSettings.self, from: old)
        #expect(settings.newFolders == .automatic)
        #expect(!settings.templateBarClosed)
    }

    @Test func keepsWhatItSaysOfTemplatesOnTheTrip() throws {
        var settings = FolderSettings(enabledModules: [], templates: [:])
        settings.newFolders = .template(id: "client")
        settings.templateBarClosed = true
        let decoded = try JSONDecoder().decode(
            FolderSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func settingsWithNoModuleOnHaveNotBeenReviewed() {
        #expect(!FolderSettings(enabledModules: [], templates: [:]).isReviewed)
        #expect(FolderSettings(enabledModules: ["m"], templates: [:]).isReviewed)
    }
}
