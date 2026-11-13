import TreewiseModuleInterface

/// How an add-on's card in Settings' Add-ons tab shows (ADR 0092): whether it is on and
/// can be switched, whether it is open or folded to its header, and the tone of its badge.
///
/// Invariant: a card is folded only when the user turned its add-on off; one that may not
/// work stays open, so what it does and its trial stay in view.
public struct AddOnCard: Equatable, Sendable {
    /// The tone of the badge, by the add-on's licence.
    public enum Tone: Equatable, Sendable {
        case free, licensed, trial, notTried, needsLicence
    }

    /// Whether the add-on is on: chosen on, and allowed to work.
    public let isOn: Bool
    /// Whether its switch can be used: not while it may not work, nor while it is the last
    /// add-on on that may work (ADR 0070).
    public let canSwitch: Bool
    /// Whether the card shows its body, or only its header.
    public let isOpen: Bool
    public let tone: Tone

    /// Whether On in new folders can be changed: only while the add-on is on.
    public var newFoldersEnabled: Bool { isOn }

    /// The card of an add-on chosen on or off (`isOnSetting`), with its licence when it is
    /// paid, and `isLastWorking` when it is the last add-on on that may work.
    public init(isOnSetting: Bool, licence: ModuleLicenceState?, isLastWorking: Bool) {
        let isLocked = licence.map { !$0.mayWork } ?? false
        isOn = isOnSetting && !isLocked
        canSwitch = !isLocked && !(isOn && isLastWorking)
        isOpen = isOn || isLocked
        tone =
            switch licence {
            case nil: .free
            case .licensed: .licensed
            case .trial: .trial
            case .notTried: .notTried
            case .unlicensed: .needsLicence
            }
    }
}
