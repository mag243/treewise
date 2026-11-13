import TreewiseModuleInterface

/// How an add-on's card in Settings' Add-ons tab shows (ADR 0092): whether it is on and
/// can be switched, and the tone of its badge. Whether it is open is the tab's selection.
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
    public let tone: Tone

    /// Whether On in new folders can be changed: while the add-on is on, and not when it is
    /// the last add-on on in new folders, which stays on there (ADR 0070).
    public let newFoldersCanSwitch: Bool

    /// The card of an add-on chosen on or off (`isOnSetting`), with its licence when it is
    /// paid, `isLastWorking` when it is the last add-on on that may work, and
    /// `isLastInNewFolders` when it is the last add-on on in new folders.
    public init(
        isOnSetting: Bool, licence: ModuleLicenceState?, isLastWorking: Bool,
        isLastInNewFolders: Bool = false
    ) {
        let isLocked = licence.map { !$0.mayWork } ?? false
        isOn = isOnSetting && !isLocked
        canSwitch = !isLocked && !(isOn && isLastWorking)
        newFoldersCanSwitch = isOn && !isLastInNewFolders
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
