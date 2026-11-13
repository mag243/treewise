import Testing
import TreewiseModuleInterface
import TreewiseUI

/// An add-on's card in Settings' Add-ons tab (ADR 0092): on, switchable, open or folded,
/// and the tone of its badge.
@Suite struct AddOnCardTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let chosenOn: Bool
        let licence: ModuleLicenceState?
        let isLastWorking: Bool
        let isOn: Bool
        let canSwitch: Bool
        let isOpen: Bool

        var testDescription: String {
            "chosen \(chosenOn ? "on" : "off"), \(licence.map { "\($0)" } ?? "free")"
                + (isLastWorking ? ", last working" : "")
        }
    }

    private static let licensed = ModuleLicenceState.licensed(licensee: "Test")

    private static let cases: [Case] = [
        Case(
            chosenOn: true, licence: nil, isLastWorking: false,
            isOn: true, canSwitch: true, isOpen: true),
        Case(
            chosenOn: false, licence: nil, isLastWorking: false,
            isOn: false, canSwitch: true, isOpen: false),
        Case(
            chosenOn: true, licence: nil, isLastWorking: true,
            isOn: true, canSwitch: false, isOpen: true),
        Case(
            chosenOn: true, licence: licensed, isLastWorking: false,
            isOn: true, canSwitch: true, isOpen: true),
        Case(
            chosenOn: false, licence: licensed, isLastWorking: false,
            isOn: false, canSwitch: true, isOpen: false),
        Case(
            chosenOn: false, licence: .trial(daysLeft: 3), isLastWorking: false,
            isOn: false, canSwitch: true, isOpen: false),
        Case(
            chosenOn: true, licence: .notTried, isLastWorking: false,
            isOn: false, canSwitch: false, isOpen: true),
        Case(
            chosenOn: false, licence: .notTried, isLastWorking: false,
            isOn: false, canSwitch: false, isOpen: true),
        Case(
            chosenOn: true, licence: .unlicensed, isLastWorking: false,
            isOn: false, canSwitch: false, isOpen: true),
        Case(
            chosenOn: false, licence: .unlicensed, isLastWorking: true,
            isOn: false, canSwitch: false, isOpen: true),
    ]

    @Test(arguments: cases)
    func foldsOnlyAnAddOnTheUserTurnedOff(_ expected: Case) {
        let card = AddOnCard(
            isOnSetting: expected.chosenOn, licence: expected.licence,
            isLastWorking: expected.isLastWorking)
        #expect(card.isOn == expected.isOn)
        #expect(card.canSwitch == expected.canSwitch)
        #expect(card.isOpen == expected.isOpen)
        #expect(card.newFoldersEnabled == expected.isOn)
    }

    @Test(
        arguments: [
            (nil, AddOnCard.Tone.free),
            (licensed, .licensed),
            (.trial(daysLeft: 3), .trial),
            (.notTried, .notTried),
            (.unlicensed, .needsLicence),
        ] as [(ModuleLicenceState?, AddOnCard.Tone)])
    func tonesTheBadgeByTheLicence(licence: ModuleLicenceState?, tone: AddOnCard.Tone) {
        #expect(AddOnCard(isOnSetting: true, licence: licence, isLastWorking: false).tone == tone)
    }
}
