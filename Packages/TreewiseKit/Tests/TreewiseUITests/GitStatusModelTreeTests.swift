import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// The sidebar tree's folders inside a repository show their state as the list does, and a
/// repository open in the tree is followed while it is open (ADR 0149).
@MainActor
@Suite struct GitStatusModelTreeTests {
    let reader = ScriptedGitReader()
    let top: FileItem.ID = "/work/tidepool"
    let sources: FileItem.ID = "/work/tidepool/Sources"
    let changed = "1 .M N... 100644 100644 100644 a b Sources/main.swift"

    private func model() -> GitStatusModel {
        GitStatusModel(reader: reader, isEnabled: true, pause: .zero)
    }

    private func settles(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<1_000 {
            if condition() { return true }
            await Task.yield()
        }
        return condition()
    }

    @Test func aFolderInTheTreeShowsTheStateOfWhatItHolds() async {
        reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }

        #expect(await settles { model.state(ofFolder: sources) == .modified })
    }

    @Test func theTopFolderShowsItsMarkAndNoState() async {
        reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }

        #expect(await settles { model.state(ofFolder: sources) != nil })
        #expect(model.state(ofFolder: top) == nil)
    }

    @Test func aRepositoryNothingFollowsShowsNoState() {
        reader.addRepository(at: top, porcelain: changed)

        #expect(model().state(ofFolder: sources) == nil)
    }

    @Test func aRepositoryOpenInTheTreeIsFollowedWhileItIsOpen() async {
        reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let open = Task { await model.follow(top) }

        #expect(await settles { model.state(ofFolder: sources) == .modified })
        open.cancel()
        #expect(await settles { reader.watchedRepositories.isEmpty })
    }

    @Test func aFolderOutsideTheRepositoryShowsNoState() async {
        reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }

        #expect(await settles { model.state(ofFolder: sources) != nil })
        #expect(model.state(ofFolder: "/work/scratch") == nil)
    }

    @Test func theTreeHearsWhenARepositoryIsRead() async {
        reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let before = model.revision
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }

        #expect(await settles { model.revision != before })
    }

    @Test func turnedOffTheTreeShowsNoState() async {
        reader.addRepository(at: top, porcelain: changed)
        let model = model()
        let tab = Task { await model.follow(sources) }
        defer { tab.cancel() }
        #expect(await settles { model.state(ofFolder: sources) != nil })

        model.isEnabled = false

        #expect(model.state(ofFolder: sources) == nil)
    }
}
