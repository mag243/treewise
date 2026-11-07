import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
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
        #expect(context.trialStart == nil)
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

    @Test func startsTheTrialOnceInBothPlaces() {
        _ = keeper().startTrial()
        _ = keeper(at: Self.start.addingTimeInterval(3 * Self.day)).startTrial()
        #expect(keeper().context().trialStart == Self.start)
        #expect(secure.value(for: LicenceKeeper.trialStartKey) != nil)
    }

    @Test func aTrialStartRemovedFromOnePlaceComesBackFromTheOther() {
        _ = keeper().startTrial()
        secure.setValue(nil, for: LicenceKeeper.trialStartKey)
        #expect(keeper().context().trialStart == Self.start)
        #expect(secure.value(for: LicenceKeeper.trialStartKey) != nil, "and is kept there again")
    }

    @Test func remembersTheLatestDaySeenWhichOnlyMovesForward() {
        _ = keeper(at: Self.start.addingTimeInterval(5 * Self.day)).context()
        let context = keeper(at: Self.start).context()
        #expect(context.lastSeen == Self.start.addingTimeInterval(5 * Self.day))
    }

    @Test func aTrialStartGivenAtLaunchStandsInForTheKeptOne() {
        let given = Self.start.addingTimeInterval(-20 * Self.day)
        let keeper = LicenceKeeper(
            settings: BrowserSettings(store: settings), secure: secure, now: { Self.start },
            trialStart: given)
        #expect(keeper.context().trialStart == given)
    }
}
