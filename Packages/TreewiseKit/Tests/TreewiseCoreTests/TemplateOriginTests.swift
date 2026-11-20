import Foundation
import Testing
import TreewiseCore

/// A folder keeps the ids of the templates it was made from, and a template's file keeps
/// its id through Export and Import (ADR 0141).
@Suite struct TemplateOriginTests {
    private let template = FolderTemplate(
        id: "A1B2", name: "Household Year",
        root: FolderTree(name: FolderTree.yearField, folders: [FolderTree(name: "Tax")]))

    @Test func aTemplatesFileHoldsItsID() throws {
        let data = try FolderTemplateFile.data(of: template)
        #expect(FolderTemplateFile.id(in: data) == "A1B2")
    }

    @Test func aFileWrittenWithoutAnIDHasNone() {
        let json = #"{"format": 1, "name": "Old", "root": {"name": "{year}", "folders": []}}"#
        #expect(FolderTemplateFile.id(in: Data(json.utf8)) == nil)
    }

    @Test func settingsSavedWithoutTemplatesHaveNone() throws {
        let stored = Data(#"{"enabledModules":[],"templates":{}}"#.utf8)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: stored).madeFrom.isEmpty)
    }

    @Test func keepsTheTemplatesThroughEncoding() throws {
        var settings = FolderSettings(enabledModules: [], templates: [:])
        settings.remember(madeFrom: "A1B2")
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data).madeFrom == ["A1B2"])
    }

    @Test func aTemplateUsedAgainMovesToTheEnd() {
        var settings = FolderSettings(enabledModules: [], templates: [:])
        for id in ["A", "B", "A"] { settings.remember(madeFrom: id) }
        #expect(settings.madeFrom == ["B", "A"], "the one used last comes last")
    }

    @Test func forgetsOneTemplate() {
        var settings = FolderSettings(enabledModules: [], templates: [:])
        for id in ["A", "B"] { settings.remember(madeFrom: id) }
        settings.forget(madeFrom: "A")
        #expect(settings.madeFrom == ["B"])
    }

    @Test func keepsTheTemplatesWithWhatItSaysOfTemplates() {
        var stored = FolderSettings(enabledModules: [], templates: [:])
        stored.remember(madeFrom: "A")
        var reviewed = FolderSettings.new(defaultModuleID: "free")
        reviewed.keepTemplates(of: stored)
        #expect(reviewed.madeFrom == ["A"])
    }
}
