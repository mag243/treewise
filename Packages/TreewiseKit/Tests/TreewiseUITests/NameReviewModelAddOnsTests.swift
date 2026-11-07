import Foundation
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

/// The licence goes with every question to a module (ADR 0071).
extension NameReviewModelTests {
    @Test func asksAModuleWithTheLicenceKeysAndTheTrialsDates() async {
        _ = addFile("scan.txt")
        let licence = LicenceContext(keys: ["TW1-x"], trialStart: Date(), lastSeen: Date())
        let host = host()
        _ = await model(host, licence: licence)
        #expect(host.requests.last?.licence == licence)
    }
}

/// What was chosen for an add-on that may not work stays chosen (ADR 0070, ADR 0071).
extension NameReviewModelTests {
    @Test func keepsTheFoldersChoiceForAnAddOnTurnedOffInSettings() async {
        _ = addFile("scan.pdf")
        await store.save(
            FolderSettings(enabledModules: [Self.free, Self.paid], templates: [:]),
            forFolderAt: "review")
        var addOns = AddOnPreferences()
        addOns.setOn(Self.paid, on: false, catalog: [Self.free, Self.paid])
        let model = await model(
            host(modules: [Self.freeDescription, Self.paidDescription]), addOns: addOns)
        await model.moveModule(Self.free, to: 0)
        #expect(
            await store.settings(forFolderAt: "review")?.enabledModules.contains(Self.paid) == true)
    }
}

/// An add-on without a licence (ADR 0071).
extension NameReviewModelTests {
    private func unlicensedHost(_ modules: [NameModuleDescription]) -> ScriptedModuleHost {
        let host = host(
            modules: modules,
            answers: [
                Self.free: .success([["text": .text("New")]]),
                Self.paid: .success([["company": .text("Co")]]),
            ])
        host.setLicenceState(.unlicensed, for: Self.paid)
        return host
    }

    @Test func showsAnAddOnWithoutALicenceAsOffAndAsksItNothing() async {
        _ = addFile("scan.pdf")
        await store.save(
            FolderSettings(enabledModules: [Self.free, Self.paid], templates: [:]),
            forFolderAt: "review")
        let host = unlicensedHost([Self.freeDescription, Self.paidDescription])
        let model = await model(host)
        let paid = model.modules.first { $0.id == Self.paid }
        #expect(paid?.isOn == false)
        #expect(paid?.licence == .unlicensed)
        #expect(model.modules.first { $0.id == Self.free }?.isOn == true)
        await model.setModule(Self.paid, on: true)
        #expect(model.modules.first { $0.id == Self.paid }?.isOn == false, "it cannot be turned on")
        #expect(
            await store.settings(forFolderAt: "review")?.enabledModules.contains(Self.paid) == true)
    }

    @Test func startsTheTrialTheFirstTimeAPaidAddOnIsOffered() async {
        _ = addFile("scan.pdf")
        let host = host(modules: [Self.freeDescription, Self.paidDescription])
        host.setLicenceState(.trial(daysLeft: 14), for: Self.paid)
        let started = TrialStarts()
        _ = await model(host, startTrial: { started.count += 1 })
        #expect(started.count == 1)
    }

    @Test func aReplacingAddOnWithoutALicenceGivesTheFreeOneBack() async {
        _ = addFile("scan.txt")
        let host = host(
            modules: [Self.freeDescription, Self.advancedDescription],
            answers: [Self.free: .success([["text": .text("New")]])])
        host.setLicenceState(.unlicensed, for: "advanced")
        let model = await model(host)
        #expect(model.modules.first { $0.id == Self.free }?.isOn == true)
        #expect(model.modules.first { $0.id == "advanced" }?.licence == .unlicensed)
    }
}

/// Counts the trial's starts, for a test.
@MainActor
final class TrialStarts {
    var count = 0
}
