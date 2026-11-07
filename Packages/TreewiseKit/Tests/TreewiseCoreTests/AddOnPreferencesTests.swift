import Foundation
import Testing
import TreewiseCore

/// What the user chose for the add-ons across the app (ADR 0070).
@Suite struct AddOnPreferencesTests {
    private static let catalog = ["free", "invoices", "photos"]

    @Test func startsWithEveryAddOnOnAndOnlyTheFreeOneInNewFolders() {
        let preferences = AddOnPreferences()
        #expect(Self.catalog.allSatisfy { preferences.isOn($0) })
        #expect(
            preferences.newFolder(catalog: Self.catalog, defaultID: "free").enabledModules == [
                "free"
            ])
    }

    @Test func turnsAnAddOnOffEverywhereButKeepsOneOn() {
        var preferences = AddOnPreferences()
        preferences.setOn("photos", on: false, catalog: Self.catalog)
        preferences.setOn("invoices", on: false, catalog: Self.catalog)
        #expect(preferences.available(Self.catalog) == ["free"])
        preferences.setOn("free", on: false, catalog: Self.catalog)
        #expect(preferences.isOn("free"), "the last one stays on")
    }

    @Test func aNewFolderTakesTheAddOnsChosenForIt() {
        var preferences = AddOnPreferences()
        preferences.setOnInNewFolders(
            "invoices", on: true, catalog: Self.catalog, defaultID: "free")
        preferences.setOnInNewFolders("free", on: false, catalog: Self.catalog, defaultID: "free")
        let folder = preferences.newFolder(catalog: Self.catalog, defaultID: "free")
        #expect(folder.enabledModules == ["invoices"])
    }

    @Test func oneAddOnStaysOnInNewFolders() {
        var preferences = AddOnPreferences()
        preferences.setOnInNewFolders("free", on: false, catalog: Self.catalog, defaultID: "free")
        #expect(preferences.isOnInNewFolders("free", defaultID: "free"))
    }

    @Test func anAddOnTurnedOffIsNotOnInNewFolders() {
        var preferences = AddOnPreferences()
        preferences.setOnInNewFolders(
            "invoices", on: true, catalog: Self.catalog, defaultID: "free")
        preferences.setOn("invoices", on: false, catalog: Self.catalog)
        #expect(
            preferences.newFolder(catalog: Self.catalog, defaultID: "free").enabledModules == [
                "free"
            ])
    }

    @Test func aNewFolderFallsBackToTheFirstAddOnThatIsOn() {
        var preferences = AddOnPreferences()
        preferences.setOn("free", on: false, catalog: Self.catalog)
        #expect(
            preferences.newFolder(catalog: Self.catalog, defaultID: "free").enabledModules
                == ["invoices"])
    }

    @Test func ordersByTheDefaultOrderWithNewOnesLast() {
        var preferences = AddOnPreferences()
        preferences.move("photos", to: 0, catalog: Self.catalog)
        #expect(preferences.ordered(Self.catalog) == ["photos", "free", "invoices"])
        #expect(preferences.ordered(Self.catalog + ["new"]).last == "new")
    }

    @Test func aNewFolderTakesTheDefaultOrder() {
        var preferences = AddOnPreferences()
        preferences.setOnInNewFolders(
            "invoices", on: true, catalog: Self.catalog, defaultID: "free")
        preferences.move("invoices", to: 0, catalog: Self.catalog)
        let folder = preferences.newFolder(catalog: Self.catalog, defaultID: "free")
        #expect(folder.enabledModules == ["invoices", "free"])
    }

    @Test func roundTripsAsJSON() throws {
        var preferences = AddOnPreferences()
        preferences.setOn("photos", on: false, catalog: Self.catalog)
        preferences.move("invoices", to: 0, catalog: Self.catalog)
        let data = try JSONEncoder().encode(preferences)
        #expect(try JSONDecoder().decode(AddOnPreferences.self, from: data) == preferences)
    }
}

/// Settings' choices for a module that another replaces go to that one (ADR 0067, ADR 0070).
@Suite struct AddOnPreferencesHandOverTests {
    @Test func handsTheChoicesForAReplacedModuleOver() {
        let catalog = ["free", "invoices"]
        var preferences = AddOnPreferences()
        preferences.setOnInNewFolders("invoices", on: true, catalog: catalog, defaultID: "free")
        preferences.move("invoices", to: 0, catalog: catalog)
        preferences.setOn("free", on: false, catalog: catalog)
        preferences.handOver(from: "free", to: "advanced")
        let next = ["advanced", "invoices"]
        #expect(!preferences.isOn("advanced"))
        #expect(preferences.isOnInNewFolders("advanced", defaultID: "advanced"))
        #expect(preferences.ordered(next) == ["invoices", "advanced"])
    }
}
