import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// The keys, the trial's start and the latest day seen, as the app keeps them (ADR 0071).
@MainActor
@Suite struct LicenceKeeperTests {
    private let settings = MemorySettingsStore()
    private let secure = MemorySecureStore()
    private static let day: TimeInterval = 24 * 60 * 60
    private static let start = Date(timeIntervalSince1970: 1_793_000_000)

    private func keeper(at now: Date = start) -> LicenceKeeper {
        LicenceKeeper(settings: BrowserSettings(store: settings), secure: secure, now: { now })
    }

    @Test func hasNoKeysAndNoTrialAtFirst() {
        let context = keeper().context()
        #expect(context.keys.isEmpty)
        #expect(context.trialStarts.isEmpty)
    }

    @Test func keepsAKeyThatLooksLikeOne() {
        let keeper = keeper()
        #expect(keeper.add(key: "  TW1-abc.def \n"))
        #expect(!keeper.add(key: "hello"))
        #expect(self.keeper().context().keys == ["TW1-abc.def"])
    }

    @Test func keepsAKeyOnce() {
        let keeper = keeper()
        _ = keeper.add(key: "TW1-abc.def")
        _ = keeper.add(key: "TW1-abc.def")
        #expect(keeper.context().keys == ["TW1-abc.def"])
    }

    /// Each add-on has one trial, started when the user asks (ADR 0088).
    @Test func startsAnAddOnsTrialOnceInBothPlaces() {
        keeper().startTrial(of: "paid")
        keeper(at: Self.start.addingTimeInterval(3 * Self.day)).startTrial(of: "paid")
        #expect(keeper().context().trialStart(of: "paid") == Self.start)
        #expect(secure.value(for: LicenceKeeper.trialStartsKey)?.contains("paid") == true)
    }

    @Test func startsEachAddOnsTrialOnItsOwn() {
        keeper().startTrial(of: "paid")
        let later = Self.start.addingTimeInterval(20 * Self.day)
        keeper(at: later).startTrial(of: "invoices")
        let context = keeper().context()
        #expect(context.trialStart(of: "paid") == Self.start)
        #expect(context.trialStart(of: "invoices") == later)
        #expect(context.trialStart(of: "other") == nil)
    }

    @Test func aTrialStartRemovedFromOnePlaceComesBackFromTheOther() {
        keeper().startTrial(of: "paid")
        secure.setValue(nil, for: LicenceKeeper.trialStartsKey)
        #expect(keeper().context().trialStart(of: "paid") == Self.start)
        #expect(
            secure.value(for: LicenceKeeper.trialStartsKey)?.contains("paid") == true,
            "and is kept there again")
        BrowserSettings(store: settings).licenceTrialStarts = [:]
        #expect(keeper().context().trialStart(of: "paid") == Self.start)
        #expect(BrowserSettings(store: settings).licenceTrialStarts["paid"] != nil)
    }

    @Test func forgetsTheOneTrialStartKeptBefore() {
        secure.setValue(Self.start.ISO8601Format(), for: "licence.trialStart")
        settings.setSetting(Self.start.ISO8601Format(), for: "licenceTrialStart")
        let context = keeper().context()
        #expect(context.trialStarts.isEmpty)
        #expect(secure.value(for: "licence.trialStart") == nil)
        #expect(settings.setting("licenceTrialStart") == nil)
    }

    @Test func remembersTheLatestDaySeenWhichOnlyMovesForward() {
        _ = keeper(at: Self.start.addingTimeInterval(5 * Self.day)).context()
        let context = keeper(at: Self.start).context()
        #expect(context.lastSeen == Self.start.addingTimeInterval(5 * Self.day))
    }

    @Test func aTrialStartGivenAtLaunchStandsInForEachStartedTrial() {
        keeper().startTrial(of: "paid")
        let given = Self.start.addingTimeInterval(-20 * Self.day)
        let keeper = LicenceKeeper(
            settings: BrowserSettings(store: settings), secure: secure, now: { Self.start },
            trialStart: given)
        #expect(keeper.context().trialStarts == ["paid": given])
    }
}

/// Entering a key: the modules say what it unlocks (ADR 0071).
@MainActor
@Suite struct LicenceKeyEntryTests {
    private static let paid = NameModuleDescription(
        id: "paid", contentTypes: ["public.item"], neededContent: [], fields: [],
        defaultTemplate: "{folder}")
    private static let free = NameModuleDescription(
        id: "free", contentTypes: ["public.item"], neededContent: [], fields: [],
        defaultTemplate: "{folder}", isFree: true)
    private let settings = BrowserSettings(store: MemorySettingsStore())

    private func keeper() -> LicenceKeeper {
        LicenceKeeper(settings: settings, secure: MemorySecureStore())
    }

    @Test func keepsAKeyThatUnlocksAModule() async {
        let host = ScriptedModuleHost(modules: [Self.free, Self.paid], answers: [:])
        host.setLicenceState(.licensed(licensee: "Ada Lovelace"), for: "paid")
        let outcome = await keeper().enter(key: "TW1-abc.def", host: host)
        #expect(outcome == .unlocked(modules: ["paid"], licensee: "Ada Lovelace"))
        #expect(settings.licenceKeys == ["TW1-abc.def"])
    }

    @Test func dropsAKeyThatUnlocksNothing() async {
        let host = ScriptedModuleHost(modules: [Self.paid], answers: [:])
        host.setLicenceState(.unlicensed, for: "paid")
        #expect(await keeper().enter(key: "TW1-abc.def", host: host) == .unlocksNothing)
        #expect(settings.licenceKeys.isEmpty)
    }

    @Test func refusesTextThatIsNoKey() async {
        let host = ScriptedModuleHost(modules: [Self.paid], answers: [:])
        #expect(await keeper().enter(key: "hello", host: host) == .notAKey)
    }
}
