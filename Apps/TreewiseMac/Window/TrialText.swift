/// What the button that starts a paid add-on's trial says, in each place it shows.
enum TrialText {
    /// How long a trial lasts. The paid add-ons decide it, in the closed licence package
    /// (`LicenceChecker.trialDays`, ADR 0071); this says the same number.
    static let days = 14

    static var tryIt: String { String(localized: "Try for \(days) Days") }
}
