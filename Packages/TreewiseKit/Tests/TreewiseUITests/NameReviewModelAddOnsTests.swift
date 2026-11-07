import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
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

/// A module that replaces the free one, as the advanced folder pattern module does (ADR 0067).
extension NameReviewModelTests {
    static let advancedDescription = NameModuleDescription(
        id: "advanced", contentTypes: ["public.item"], neededContent: [],
        fields: [.init(name: "date", kind: .date), .init(name: "text", kind: .text)],
        defaultTemplate: "Adv {text}", name: "Advanced", replaces: [free])

    private func replacingHost() -> ScriptedModuleHost {
        let host = ScriptedModuleHost(
            modules: [Self.freeDescription, Self.advancedDescription],
            answers: ["advanced": .success([["text": .text("New")]])])
        host.setDerivedTemplate("Doc {text}", for: "advanced")
        return host
    }

    @Test func offersTheReplacingModuleInsteadOfTheFreeOne() async {
        _ = addFile("scan.txt")
        let model = await model(replacingHost())
        #expect(model.modules.map(\.id) == ["advanced"])
        #expect(model.modules.first?.isOn == true, "it is on in a new folder, as the free one was")
    }

    @Test func theReplacingModuleTakesTheFoldersSettingsForTheFreeOne() async {
        let item = addFile("scan.txt")
        await store.save(
            FolderSettings(enabledModules: [Self.free], templates: [Self.free: "Mine {text}"]),
            forFolderAt: "review")
        let model = await model(replacingHost())
        #expect(model.modules.first?.isOn == true)
        #expect(model.modules.first?.templateText == "Mine {text}")
        #expect(model.session?.entry(item.id)?.currentName == "Mine New.txt")
    }

    @Test func theReplacingModuleTakesTheChoicesInSettingsForTheFreeOne() async {
        _ = addFile("scan.txt")
        var addOns = AddOnPreferences()
        addOns.setOnInNewFolders(
            Self.paid, on: true, catalog: [Self.free, Self.paid], defaultID: Self.free)
        addOns.move(Self.paid, to: 0, catalog: [Self.free, Self.paid])
        let model = await model(
            ScriptedModuleHost(
                modules: [Self.freeDescription, Self.paidDescription, Self.advancedDescription],
                answers: [:]), addOns: addOns)
        #expect(model.modules.map(\.id) == [Self.paid, "advanced"])
    }
}
