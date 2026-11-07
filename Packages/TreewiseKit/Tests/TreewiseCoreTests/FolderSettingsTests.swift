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

    @Test func ordersModulesAsTheCatalogWithoutAnOrderOfItsOwn() {
        let settings = FolderSettings(enabledModules: ["a"], templates: [:])
        #expect(settings.ordered(["a", "b", "c"]) == ["a", "b", "c"])
    }

    @Test func keepsTheUsersOrderAndPutsAModuleNewToTheFolderLast() {
        var settings = FolderSettings(enabledModules: ["a", "b"], templates: [:])
        settings.moveModule("b", to: 0, catalog: ["a", "b"])
        #expect(settings.ordered(["a", "b", "c"]) == ["b", "a", "c"])
    }

    @Test func movingAModuleReordersTheModulesThatAreOn() {
        var settings = FolderSettings(enabledModules: ["a", "c"], templates: [:])
        settings.moveModule("c", to: 0, catalog: ["a", "b", "c"])
        #expect(settings.enabledModules == ["c", "a"])
        #expect(settings.moduleOrder == ["c", "a", "b"])
    }

    @Test func aModuleTurnedOnAgainComesBackAtItsPlace() {
        var settings = FolderSettings(enabledModules: ["a", "b"], templates: [:])
        settings.moveModule("b", to: 0, catalog: ["a", "b"])
        settings.setModule("b", on: false, order: settings.ordered(["a", "b"]))
        settings.setModule("b", on: true, order: settings.ordered(["a", "b"]))
        #expect(settings.enabledModules == ["b", "a"])
    }

    @Test func settingsStoredWithoutAnOrderStillLoad() throws {
        let stored = Data(#"{"enabledModules":["a"],"templates":{}}"#.utf8)
        let settings = try JSONDecoder().decode(FolderSettings.self, from: stored)
        #expect(settings.moduleOrder.isEmpty)
        #expect(settings.alwaysSkipped.isEmpty)
    }

    @Test func settingsSurviveEncoding() throws {
        var settings = FolderSettings(enabledModules: ["a"], templates: ["a": "{number}"])
        settings.alwaysSkipped = ["b"]
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data) == settings)
    }
}

/// A folder's settings for a module that another replaces go to that one (ADR 0067).
@Suite struct FolderSettingsHandOverTests {
    @Test func handsTheModuleOnItsPatternAndItsPlaceOver() {
        var settings = FolderSettings(
            enabledModules: ["free", "invoices"], templates: ["free": "A {text}"])
        settings.moduleOrder = ["invoices", "free"]
        settings.handOver(from: "free", to: "advanced")
        #expect(Set(settings.enabledModules) == ["advanced", "invoices"])
        #expect(settings.templates == ["advanced": "A {text}"])
        #expect(settings.moduleOrder == ["invoices", "advanced"])
    }

    @Test func keepsTheReplacingModulesOwnPattern() {
        var settings = FolderSettings(
            enabledModules: ["free", "advanced"],
            templates: ["free": "A {text}", "advanced": "B {text}"])
        settings.handOver(from: "free", to: "advanced")
        #expect(settings.enabledModules == ["advanced"])
        #expect(settings.templates == ["advanced": "B {text}"])
    }
}

/// A module not shown, as one turned off in Settings, keeps its place among those on
/// (ADR 0070).
@Suite struct FolderSettingsUnshownTests {
    @Test func movingKeepsAModuleNotShownOn() {
        var settings = FolderSettings(enabledModules: ["a", "hidden"], templates: [:])
        settings.moveModule("b", to: 0, catalog: ["a", "b"])
        #expect(settings.enabledModules.contains("hidden"))
    }

    @Test func turningOnKeepsAModuleNotShownOn() {
        var settings = FolderSettings(enabledModules: ["a", "hidden"], templates: [:])
        settings.setModule("b", on: true, order: ["a", "b"])
        #expect(Set(settings.enabledModules) == ["a", "b", "hidden"])
    }
}
