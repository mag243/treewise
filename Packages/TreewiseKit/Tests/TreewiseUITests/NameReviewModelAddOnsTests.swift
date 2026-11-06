import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI

/// What Settings decides for the add-ons, in the overview (ADR 0070).
extension NameReviewModelTests {
    private var catalog: [String] { [Self.free, Self.paid] }

    @Test func leavesOutAnAddOnTurnedOffInSettings() async {
        _ = addFile("scan.pdf")
        var addOns = AddOnPreferences()
        addOns.setOn(Self.paid, on: false, catalog: catalog)
        let model = await model(
            host(modules: [Self.freeDescription, Self.paidDescription]), addOns: addOns)
        #expect(model.modules.map(\.id) == [Self.free])
    }

    @Test func aNewFolderStartsWithTheAddOnsOnInNewFolders() async {
        _ = addFile("scan.pdf")
        var addOns = AddOnPreferences()
        addOns.setOnInNewFolders(Self.paid, on: true, catalog: catalog, defaultID: Self.free)
        addOns.move(Self.paid, to: 0, catalog: catalog)
        let model = await model(
            host(modules: [Self.freeDescription, Self.paidDescription]), addOns: addOns)
        #expect(model.modules.map(\.id) == [Self.paid, Self.free])
        #expect(model.modules.map(\.isOn) == [true, true])
    }

    @Test func aFolderWithoutItsOwnOrderTakesTheDefaultOrder() async {
        _ = addFile("scan.pdf")
        await store.save(
            FolderSettings(enabledModules: [Self.free], templates: [:]), forFolderAt: "review")
        var addOns = AddOnPreferences()
        addOns.move(Self.paid, to: 0, catalog: catalog)
        let model = await model(
            host(modules: [Self.freeDescription, Self.paidDescription]), addOns: addOns)
        #expect(model.modules.map(\.id) == [Self.paid, Self.free])
    }

    @Test func aFolderWhoseAddOnsAreAllTurnedOffTakesTheNewFolderOnes() async {
        _ = addFile("scan.pdf")
        await store.save(
            FolderSettings(enabledModules: [Self.paid], templates: [:]), forFolderAt: "review")
        var addOns = AddOnPreferences()
        addOns.setOn(Self.paid, on: false, catalog: catalog)
        let model = await model(
            host(modules: [Self.freeDescription, Self.paidDescription]), addOns: addOns)
        #expect(model.modules.map(\.id) == [Self.free])
        #expect(model.modules.first?.isOn == true)
    }
}
