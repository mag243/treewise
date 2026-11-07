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
            .licensed(licensee: "Ada"), .trial(daysLeft: 3), .unlicensed,
        ]
        let data = try JSONEncoder().encode(states)
        #expect(try JSONDecoder().decode([ModuleLicenceState].self, from: data) == states)
    }
}
