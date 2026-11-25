import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// The branch in the status bar and its tooltip, and the Git column's words (ADR 0149).
@Suite struct GitTextTests {
    private let english = Locale(identifier: "en")

    private func status(
        _ head: GitRepositoryStatus.Head?, _ upstream: GitRepositoryStatus.Upstream?
    )
        -> GitRepositoryStatus
    {
        var status = GitRepositoryStatus()
        status.head = head
        status.upstream = upstream
        return status
    }

    @Test(arguments: [
        (GitRepositoryStatus.Upstream.following(ahead: 2, behind: 1), "main ↑2 ↓1"),
        (.following(ahead: 2, behind: 0), "main ↑2"),
        (.following(ahead: 0, behind: 3), "main ↓3"),
        (.following(ahead: 0, behind: 0), "main"),
        (.gone, "main upstream gone"),
    ])
    func showsTheBranchWithTheCountsThatAreNotZero(
        _ upstream: GitRepositoryStatus.Upstream, _ text: String
    ) {
        #expect(GitText.branch(status(.branch("main"), upstream), locale: english) == text)
    }

    @Test func aBranchWithoutUpstreamIsLocalOnly() {
        #expect(GitText.branch(status(.branch("main"), nil), locale: english) == "main local only")
    }

    @Test func aDetachedHeadShowsItsHashAlone() {
        #expect(GitText.branch(status(.detached("a3f91c2"), nil), locale: english) == "a3f91c2")
    }

    @Test func withoutAHeadThereIsNoBranch() {
        #expect(GitText.branch(status(nil, nil), locale: english) == nil)
        #expect(GitText.branchHelp(status(nil, nil), locale: english) == nil)
    }

    @Test func theTooltipSaysItInASentence() {
        #expect(
            GitText.branchHelp(
                status(.branch("main"), .following(ahead: 2, behind: 1)), locale: english)
                == "On branch main: 2 commits to push, 1 commit to pull")
        #expect(
            GitText.branchHelp(
                status(.branch("main"), .following(ahead: 1, behind: 0)), locale: english)
                == "On branch main: 1 commit to push")
        #expect(
            GitText.branchHelp(
                status(.branch("main"), .following(ahead: 0, behind: 0)), locale: english)
                == "On branch main, up to date with its remote")
        #expect(
            GitText.branchHelp(status(.branch("main"), nil), locale: english)
                == "On branch main, which follows no branch on a remote")
    }

    @Test func theColumnSaysTheStateInAWord() {
        #expect(
            GitItemState.allCases.map { GitText.state($0, locale: english) } == [
                "Modified", "New", "Ignored", "Conflict",
            ])
    }
}
