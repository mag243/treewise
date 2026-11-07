import Foundation

/// When a pattern counts as recognized in a folder, the one rule for every module that
/// reads names (ADR 0067). Only the folder's files count, not its subfolders. A folder
/// being tidied up is where proposals help most, so a few odd names must not keep a
/// pattern from being recognized; nothing is renamed without the user's approval.
public enum PatternFit {
    /// The fewest files that must fit a pattern, as fewer cannot be told apart from chance.
    public static let minimumFits = 3
    /// The share of the files from which a recognized pattern is clear, and the overview
    /// stops saying how many fit it.
    private static let clearShare = (numerator: 4, denominator: 5)

    /// Whether a pattern is recognized: at least 3 files fit it, and more than half.
    public static func isRecognized(fits: Int, of files: Int) -> Bool {
        fits >= minimumFits && fits * 2 > files
    }

    /// Whether a pattern is offered beside the recognized one: at least 3 files fit it,
    /// and at least half.
    public static func isOffered(fits: Int, of files: Int) -> Bool {
        fits >= minimumFits && fits * 2 >= files
    }

    /// Whether a recognized pattern is clear: at least four fifths of the files fit it.
    public static func isClear(fits: Int, of files: Int) -> Bool {
        files > 0 && fits * clearShare.denominator >= files * clearShare.numerator
    }
}
