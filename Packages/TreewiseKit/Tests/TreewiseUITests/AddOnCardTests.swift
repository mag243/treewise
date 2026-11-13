import Testing
import TreewiseModuleInterface
import TreewiseUI

/// An add-on's card in Settings' Add-ons tab (ADR 0092): on, switchable, and the tone of
/// its badge.
@Suite struct AddOnCardTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let chosenOn: Bool
        let licence: ModuleLicenceState?
        let isLastWorking: Bool
        let isOn: Bool
        let canSwitch: Bool

        var testDescription: String {
            "chosen \(chosenOn ? "on" : "off"), \(licence.map { "\($0)" } ?? "free")"
                + (isLastWorking ? ", last working" : "")
        }
    }

    private static let licensed = ModuleLicenceState.licensed(licensee: "Test")

    private static let cases: [Case] = [
        Case(
            chosenOn: true, licence: nil, isLastWorking: false,
            isOn: true, canSwitch: true),
        Case(
            chosenOn: false, licence: nil, isLastWorking: false,
            isOn: false, canSwitch: true),
        Case(
            chosenOn: true, licence: nil, isLastWorking: true,
            isOn: true, canSwitch: false),
        Case(
            chosenOn: true, licence: licensed, isLastWorking: false,
            isOn: true, canSwitch: true),
        Case(
            chosenOn: false, licence: licensed, isLastWorking: false,
            isOn: false, canSwitch: true),
        Case(
            chosenOn: false, licence: .trial(daysLeft: 3), isLastWorking: false,
            isOn: false, canSwitch: true),
        Case(
            chosenOn: true, licence: .notTried, isLastWorking: false,
            isOn: false, canSwitch: false),
        Case(
            chosenOn: false, licence: .notTried, isLastWorking: false,
            isOn: false, canSwitch: false),
        Case(
            chosenOn: true, licence: .unlicensed, isLastWorking: false,
            isOn: false, canSwitch: false),
        Case(
            chosenOn: false, licence: .unlicensed, isLastWorking: true,
            isOn: false, canSwitch: false),
    ]

    @Test(arguments: cases)
    func switchesOnlyAnAddOnThatMayWork(_ expected: Case) {
        let card = AddOnCard(
            isOnSetting: expected.chosenOn, licence: expected.licence,
            isLastWorking: expected.isLastWorking)
        #expect(card.isOn == expected.isOn)
        #expect(card.canSwitch == expected.canSwitch)
        #expect(card.newFoldersCanSwitch == expected.isOn)
    }

    @Test func onInNewFoldersCannotBeTurnedOffForTheLastAddOnOnThere() {
        let last = AddOnCard(
            isOnSetting: true, licence: nil, isLastWorking: false, isLastInNewFolders: true)
        #expect(!last.newFoldersCanSwitch)
        let other = AddOnCard(
            isOnSetting: true, licence: nil, isLastWorking: false, isLastInNewFolders: false)
        #expect(other.newFoldersCanSwitch)
        let off = AddOnCard(
            isOnSetting: false, licence: nil, isLastWorking: false, isLastInNewFolders: false)
        #expect(!off.newFoldersCanSwitch)
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
