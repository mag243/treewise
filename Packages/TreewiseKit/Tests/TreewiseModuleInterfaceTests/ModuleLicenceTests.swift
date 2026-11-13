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
                licence: LicenceContext(keys: ["TW1-x"], trialStarts: [:], lastSeen: nil)) == nil)
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
            .notTried, .trial(daysLeft: 3), .unlicensed,
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
        ModuleLicenceState.licensed(licensee: "Ada"), .notTried, .trial(daysLeft: 3), .unlicensed,
    ])
    func hasNoDaysLeftWithoutAnEndDate(_ state: ModuleLicenceState) {
        #expect(state.daysLeft(now: Self.day(10), calendar: Self.calendar) == nil)
    }

    @Test(arguments: [
        (ModuleLicenceState.licensed(licensee: "Ada"), true), (.trial(daysLeft: 1), true),
        (.notTried, false), (.unlicensed, false),
    ])
    func mayWorkWithALicenceOrInItsTrialOnly(_ state: ModuleLicenceState, _ works: Bool) {
        #expect(state.mayWork == works)
    }

    /// Each add-on has its own trial start (ADR 0088).
    @Test func aContextHoldsATrialStartForEachModule() throws {
        let context = LicenceContext(
            keys: [], trialStarts: ["paid": Self.day(3)], lastSeen: Self.day(5))
        #expect(context.trialStart(of: "paid") == Self.day(3))
        #expect(context.trialStart(of: "other") == nil)
        let data = try JSONEncoder().encode(context)
        #expect(try JSONDecoder().decode(LicenceContext.self, from: data) == context)
    }
}

/// An add-on says in one line what it does, in English, Dutch and German (ADR 0088).
@Suite struct ModuleSummaryTests {
    private static let module = NameModuleDescription(
        id: "paid", contentTypes: [], neededContent: [], fields: [], defaultTemplate: "",
        summaries: ["en": "Recognizes more patterns.", "nl": "Herkent meer patronen."])

    @Test(arguments: [
        (["nl-NL", "en"], "Herkent meer patronen."), (["nl"], "Herkent meer patronen."),
        (["de-DE", "nl-NL"], "Herkent meer patronen."), (["en-GB"], "Recognizes more patterns."),
        (["fr-FR"], "Recognizes more patterns."), ([], "Recognizes more patterns."),
    ])
    func saysItInTheFirstLanguageItHasElseEnglish(_ languages: [String], _ summary: String) {
        #expect(Self.module.summary(preferring: languages) == summary)
    }

    @Test func saysWhatItRecognizesAsWrittenInAPattern() {
        let module = NameModuleDescription(
            id: "paid", contentTypes: [], neededContent: [], fields: [], defaultTemplate: "",
            recognizes: ["{date}", "{year}", "{seq:4}"])
        #expect(module.recognizes == ["{date}", "{year}", "{seq:4}"])
    }

    @Test func aModuleWithoutASummarySaysNothing() {
        let bare = NameModuleDescription(
            id: "free", contentTypes: [], neededContent: [], fields: [], defaultTemplate: "")
        #expect(bare.summary(preferring: ["en"]) == nil)
    }
}
