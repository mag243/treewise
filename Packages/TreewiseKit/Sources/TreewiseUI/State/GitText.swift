import Foundation
import TreewiseCore

/// The words of git status: the branch in the status bar with its tooltip, and an item's
/// state in the Git column (ADR 0149).
public enum GitText {
    /// The branch as the status bar shows it: `main ↑2 ↓1`, counts of zero left out;
    /// `main local only` without an upstream, `main upstream gone` when it was deleted; a
    /// detached HEAD by its short hash. `nil` when git did not say where HEAD is.
    public static func branch(_ status: GitRepositoryStatus, locale: Locale) -> String? {
        let bundle = Bundle.module.localizationBundle(for: locale)
        switch status.head {
        case nil: return nil
        case .detached(let hash): return hash
        case .branch(let name):
            switch status.upstream {
            case nil:
                return String(localized: "\(name) local only", bundle: bundle, locale: locale)
            case .gone:
                return String(localized: "\(name) upstream gone", bundle: bundle, locale: locale)
            case .following(let ahead, let behind):
                let counts = [ahead > 0 ? "↑\(ahead)" : nil, behind > 0 ? "↓\(behind)" : nil]
                return ([name] + counts.compactMap(\.self)).joined(separator: " ")
            }
        }
    }

    /// The branch said in a sentence, for the status bar's tooltip.
    public static func branchHelp(_ status: GitRepositoryStatus, locale: Locale) -> String? {
        let bundle = Bundle.module.localizationBundle(for: locale)
        switch status.head {
        case nil: return nil
        case .detached(let hash):
            return String(
                localized: "HEAD is at commit \(hash), on no branch", bundle: bundle,
                locale: locale)
        case .branch(let name):
            switch status.upstream {
            case nil:
                return String(
                    localized: "On branch \(name), which follows no branch on a remote",
                    bundle: bundle, locale: locale)
            case .gone:
                return String(
                    localized: "On branch \(name), whose branch on the remote was deleted",
                    bundle: bundle, locale: locale)
            case .following(0, 0):
                return String(
                    localized: "On branch \(name), up to date with its remote", bundle: bundle,
                    locale: locale)
            case .following(let ahead, let behind):
                return String(
                    localized:
                        "On branch \(name): \(ahead) commits to push, \(behind) to pull",
                    bundle: bundle, locale: locale)
            }
        }
    }

    /// An item's state in words, as the Git column shows it.
    public static func state(_ state: GitItemState, locale: Locale) -> String {
        let bundle = Bundle.module.localizationBundle(for: locale)
        switch state {
        case .modified:
            return String(
                localized: "Modified", bundle: bundle, locale: locale,
                comment: "An item's state in its git repository, in the Git column")
        case .new:
            return String(
                localized: "New", bundle: bundle, locale: locale,
                comment: "An item's state in its git repository, in the Git column")
        case .ignored:
            return String(
                localized: "Ignored", bundle: bundle, locale: locale,
                comment: "An item's state in its git repository, in the Git column")
        case .conflict:
            return String(
                localized: "Conflict", bundle: bundle, locale: locale,
                comment: "An item's state in its git repository, in the Git column")
        }
    }
}
