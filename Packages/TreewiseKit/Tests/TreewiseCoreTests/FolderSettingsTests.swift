import Foundation
import Testing
import TreewiseCore

/// How settings find their folder through the id on it (ADR 0057).
@Suite struct FolderSettingsTests {
    private func place(
        idOnFolder: String? = "id", path: String = "/new", recordedPath: String? = nil,
        idAtRecordedPath: String? = nil
    ) -> FolderSettings.Place {
        FolderSettings.place(
            idOnFolder: idOnFolder, path: path, recordedPath: recordedPath,
            idAtRecordedPath: idAtRecordedPath)
    }

    @Test func aFolderWithoutAnIDIsNew() {
        #expect(place(idOnFolder: nil) == .noID)
    }

    @Test func anIDNobodyRecordedIsSomeoneElses() {
        #expect(place(recordedPath: nil) == .unknownID)
    }

    @Test func theSamePathIsTheSameFolder() {
        #expect(place(path: "/old", recordedPath: "/old", idAtRecordedPath: "id") == .same)
    }

    @Test func anEmptyOldPathMeansMoved() {
        #expect(place(recordedPath: "/old", idAtRecordedPath: nil) == .moved)
    }

    @Test func anotherFolderAtTheOldPathMeansMoved() {
        #expect(place(recordedPath: "/old", idAtRecordedPath: "other") == .moved)
    }

    @Test func theSameIDStillAtTheOldPathMeansACopy() {
        #expect(place(recordedPath: "/old", idAtRecordedPath: "id") == .copy)
    }

    @Test func aNewFolderHasOnlyTheFolderPatternModuleOn() {
        #expect(FolderSettings.new(defaultModuleID: "free").enabledModules == ["free"])
    }

    @Test func turnsAModuleOnInTheModulesOrder() {
        var settings = FolderSettings.new(defaultModuleID: "free")
        settings.setModule("paid", on: true, order: ["paid", "free"])
        #expect(settings.enabledModules == ["paid", "free"])
    }

    @Test func turnsAModuleOff() {
        var settings = FolderSettings(enabledModules: ["a", "b"], templates: [:])
        settings.setModule("a", on: false, order: ["a", "b"])
        #expect(settings.enabledModules == ["b"])
    }

    @Test func theLastModuleStaysOn() {
        var settings = FolderSettings(enabledModules: ["a"], templates: [:])
        settings.setModule("a", on: false, order: ["a"])
        #expect(settings.enabledModules == ["a"])
    }

    @Test func remembersFilesAlwaysSkipped() {
        var settings = FolderSettings.new(defaultModuleID: "free")
        settings.alwaysSkipped.insert("Budget.xlsx")
        #expect(settings.alwaysSkipped.contains("Budget.xlsx"))
    }

    @Test func settingsStoredWithTheOldDateTrustStillLoad() throws {
        let settings = FolderSettings(enabledModules: ["a"], templates: [:])
        var stored = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings))
                as? [String: Any])
        stored["trustsDatesInFiles"] = true
        let data = try JSONSerialization.data(withJSONObject: stored)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data) == settings)
    }

    @Test func settingsSurviveEncoding() throws {
        var settings = FolderSettings(enabledModules: ["a"], templates: ["a": "{number}"])
        settings.alwaysSkipped = ["b"]
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data) == settings)
    }
}
