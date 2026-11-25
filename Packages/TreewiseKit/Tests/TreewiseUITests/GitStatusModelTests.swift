import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// One git state for each repository, shared by every tab and window, read again after a
/// change and never while turned off (ADR 0149).
@MainActor
@Suite struct GitStatusModelTests {
    let reader = ScriptedGitReader()
    let top: FileItem.ID = "/work/tidepool"
    let sources: FileItem.ID = "/work/tidepool/Sources"
    let changed = "1 .M N... 100644 100644 100644 a b Sources/main.swift"

    private func model(isEnabled: Bool = true) -> GitStatusModel {
        GitStatusModel(reader: reader, isEnabled: isEnabled, pause: .zero)
    }

    /// Lets the model's tasks run until `condition` holds, without waiting on a clock;
    /// false when it never does.
    private func settles(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<1_000 {
            if condition() { return true }
            await Task.yield()
        }
        return condition()
    }

    @Test func showsTheStateOfTheItemsInAFolderOfARepository() async {
        reader.addRepository(at: top, porcelain: "# branch.head main\n\(changed)")
        let model = model()
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }

        #expect(
            await settles {
                model.state(of: "/work/tidepool/Sources/main.swift", in: sources) == .modified
            })
        #expect(model.state(of: "/work/tidepool/Sources/other.swift", in: sources) == nil)
        #expect(model.status(of: sources)?.head == .branch("main"))
    }

    @Test func aFolderOutsideARepositoryHasNoState() async {
        reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let tab = Task { await model.follow("/work/scratch") }
        defer { tab.cancel() }

        #expect(await settles { reader.lookups == 1 })
        #expect(model.status(of: "/work/scratch") == nil)
        #expect(reader.watchedRepositories.isEmpty)
    }

    @Test func tabsInOneRepositoryShareOneReading() async {
        let repository = reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let first = Task { await model.follow(sources) }
        let second = Task { await model.follow(top) }
        defer {
            first.cancel()
            second.cancel()
        }

        #expect(await settles { model.status(of: sources) != nil && model.status(of: top) != nil })
        #expect(reader.reads(of: repository) == 1)
        #expect(reader.watchedRepositories == [repository])
    }

    @Test func aChangeIsReadAgain() async {
        let repository = reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }
        #expect(await settles { model.status(of: sources) != nil })

        reader.setStatus(of: repository, porcelain: "? Sources/new.swift")
        reader.change(repository)

        #expect(
            await settles {
                model.state(of: "/work/tidepool/Sources/new.swift", in: sources) == .new
            })
        #expect(model.state(of: "/work/tidepool/Sources/main.swift", in: sources) == nil)
    }

    @Test func theLastTabToGoStopsTheFollowing() async {
        let repository = reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let first = Task { await model.follow(sources) }
        let second = Task { await model.follow(top) }
        #expect(await settles { reader.watchedRepositories == [repository] })

        first.cancel()
        await first.value
        #expect(reader.watchedRepositories == [repository], "one tab still shows it")

        second.cancel()
        await second.value
        #expect(await settles { reader.watchedRepositories.isEmpty })
        #expect(model.status(of: top) == nil)
    }

    @Test func turnedOffItReadsNothing() async {
        let repository = reader.addRepository(at: top, porcelain: changed)
        let model = model(isEnabled: false)
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }
        for _ in 0..<100 { await Task.yield() }

        #expect(reader.lookups == 0)
        #expect(reader.reads(of: repository) == 0)
        #expect(model.status(of: sources) == nil)
    }

    @Test func turningItOffStopsAndOnReadsTheShownFoldersAgain() async {
        let repository = reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }
        #expect(await settles { model.status(of: sources) != nil })

        model.isEnabled = false
        #expect(model.status(of: sources) == nil)
        #expect(await settles { reader.watchedRepositories.isEmpty })

        model.isEnabled = true
        #expect(await settles { model.status(of: sources) != nil })
        #expect(reader.reads(of: repository) == 2)
    }

    @Test func theSidebarMarksATopFolderOnlyWhileTurnedOn() {
        reader.addRepository(at: top, porcelain: "")
        let model = model()
        #expect(model.marksRepository(top))
        #expect(!model.marksRepository(sources))
        model.isEnabled = false
        #expect(!model.marksRepository(top))
    }

    @Test func withoutGitItSaysSo() {
        #expect(!GitStatusModel(reader: ScriptedGitReader(hasGit: false)).hasGit)
        #expect(model().hasGit)
    }
}
