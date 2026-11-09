#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// An archive that changes on disk is read again (ADR 0076), inside a TempDirectory.
    @Suite struct ArchiveWatchingTests: ArchiveTesting {
        /// How long a change may take to arrive: FSEvents gathers events first.
        private static let deadline = Duration.seconds(5)
        /// How long to listen for a change that must not come.
        private static let quietPeriod = Duration.seconds(1)

        private func events(_ directory: TempDirectory, _ archive: String) -> AsyncStream<Void> {
            DirectoryWatcher().changes(of: ArchivePath(archive: id(directory, archive)).id)
        }

        private func arrives(_ events: AsyncStream<Void>, within limit: Duration) async -> Bool {
            await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    var iterator = events.makeAsyncIterator()
                    return await iterator.next() != nil
                }
                group.addTask {
                    try? await Task.sleep(for: limit)
                    return false
                }
                let first = await group.next() ?? false
                group.cancelAll()
                return first
            }
        }

        private func rewrite(_ directory: TempDirectory, _ archive: String) throws {
            try directory.makeFile("src/more.txt", contents: "more")
            try ArchiveFixtures.tar([
                "--format", "zip", "-cf", directory.url(archive).path, "-C",
                directory.url("src").path, "more.txt",
            ])
        }

        @Test func reportsAnArchiveThatChanges() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let events = events(directory, "Photos.zip")

            try rewrite(directory, "Photos.zip")

            #expect(await arrives(events, within: Self.deadline))
        }

        @Test func reportsAnArchiveThatGoesAwayAndEnds() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let events = events(directory, "Photos.zip")

            try manager.removeItem(at: directory.url("Photos.zip"))

            var iterator = events.makeAsyncIterator()
            #expect(await iterator.next() != nil)
            #expect(await iterator.next() == nil)
        }

        @Test func aFileBesideTheArchiveIsNoChange() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let events = events(directory, "Photos.zip")

            try directory.makeFile("beside.txt", contents: "x")

            #expect(await !arrives(events, within: Self.quietPeriod))
        }

        @Test func anArchiveThatIsGoneHasNothingToReport() async throws {
            let directory = try TempDirectory()

            var iterator = events(directory, "Missing/Gone.zip").makeAsyncIterator()

            #expect(await iterator.next() == nil)
        }
    }
#endif
