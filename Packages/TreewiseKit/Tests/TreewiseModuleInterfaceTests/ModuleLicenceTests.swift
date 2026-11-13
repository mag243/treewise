import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface

/// What a module says about its licence (ADR 0071).
@Suite struct ModuleLicenceTests {
    private struct FreeModule: NameModule {
        let description = NameModuleDescription(
            id: "free", contentTypes: ["public.item"], neededContent: [], fields: [],
            defaultTemplate: "{folder}", isFree: true)

        func fieldValues(for request: NameRequest) async throws -> [[String: NameTemplate.Value]] {
            []
        }
    }

    @Test func aModuleWithoutALicenceHasNoState() {
        #expect(
            FreeModule().licenceState(
                licence: LicenceContext(keys: ["TW1-x"], trialStart: nil, lastSeen: nil)) == nil)
    }

    @Test func aModuleSaysWhereToBuyIt() {
        let paid = NameModuleDescription(
            id: "paid", contentTypes: [], neededContent: [], fields: [], defaultTemplate: "",
            purchaseURL: "https://example.com/buy")
        #expect(paid.purchaseURL == "https://example.com/buy")
    }

    @Test func aStateTravelsAsData() throws {
        let states: [ModuleLicenceState] = [
            .licensed(licensee: "Ada"), .licensed(licensee: "Ada", until: Self.day(30)),
            .trial(daysLeft: 3), .unlicensed,
        ]
        let data = try JSONEncoder().encode(states)
        #expect(try JSONDecoder().decode([ModuleLicenceState].self, from: data) == states)
    }

    private static let calendar = Calendar(identifier: .gregorian)

    /// The start of a day in November 2026.
    private static func day(_ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))
            ?? .distantPast
    }

    /// The last day counts as one: a key until the 30th has one day left on the 30th (ADR 0077).
    @Test(arguments: [(30, 1), (29, 2), (24, 7), (23, 8), (1, 30)])
    func countsTheDaysLeftOfAKeyWithAnEndDate(_ today: Int, _ left: Int) {
        let state = ModuleLicenceState.licensed(licensee: "Ada", until: Self.day(30))
        #expect(state.daysLeft(now: Self.day(today, hour: 15), calendar: Self.calendar) == left)
    }

    @Test(arguments: [
        ModuleLicenceState.licensed(licensee: "Ada"), .trial(daysLeft: 3), .unlicensed,
    ])
    func hasNoDaysLeftWithoutAnEndDate(_ state: ModuleLicenceState) {
        #expect(state.daysLeft(now: Self.day(10), calendar: Self.calendar) == nil)
    }
}
