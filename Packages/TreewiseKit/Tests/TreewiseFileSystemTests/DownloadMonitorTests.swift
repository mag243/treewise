#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// What a cloud service publishes reaches the list (ADR 0051).
    @Suite(.serialized) struct DownloadMonitorTests {
        /// A download as a cloud service publishes it.
        private func publishedDownload(of file: URL, totalBytes: Int64 = 10) -> Progress {
            let progress = Progress(totalUnitCount: totalBytes)
            progress.kind = .file
            progress.fileOperationKind = .downloading
            progress.fileURL = file
            progress.publish()
            return progress
        }

        private func id(of file: URL) -> FileItem.ID {
            FileItem.ID(file.path)
        }

        @Test func reportsADownloadWhenItStarts() async throws {
            let directory = try TempDirectory()
            let file = try directory.makeFile("report.pdf")
            var reports = DownloadMonitor().downloads(of: [id(of: file)]).makeAsyncIterator()

            let progress = publishedDownload(of: file)
            defer { progress.unpublish() }

            #expect(await reports.next() == [id(of: file): 0])
        }

        @Test func reportsADownloadProgressing() async throws {
            let directory = try TempDirectory()
            let file = try directory.makeFile("report.pdf")
            var reports = DownloadMonitor().downloads(of: [id(of: file)]).makeAsyncIterator()
            let progress = publishedDownload(of: file)
            defer { progress.unpublish() }
            _ = await reports.next()

            progress.completedUnitCount = 5

            var latest = await reports.next()
            while let report = latest, report[id(of: file)] == 0 { latest = await reports.next() }
            #expect(latest == [id(of: file): 0.5])
        }

        @Test func aDownloadThatEndsLeavesTheReport() async throws {
            let directory = try TempDirectory()
            let file = try directory.makeFile("report.pdf")
            var reports = DownloadMonitor().downloads(of: [id(of: file)]).makeAsyncIterator()
            let progress = publishedDownload(of: file)
            _ = await reports.next()

            progress.unpublish()

            var latest = await reports.next()
            while let report = latest, !report.isEmpty { latest = await reports.next() }
            #expect(latest?.isEmpty == true)
        }

        @Test func ignoresADownloadOfAnotherFile() async throws {
            let directory = try TempDirectory()
            let followed = try directory.makeFile("report.pdf")
            let other = try directory.makeFile("other.pdf")
            var reports = DownloadMonitor().downloads(of: [id(of: followed)]).makeAsyncIterator()

            let otherProgress = publishedDownload(of: other)
            defer { otherProgress.unpublish() }
            let progress = publishedDownload(of: followed)
            defer { progress.unpublish() }

            #expect(await reports.next() == [id(of: followed): 0])
        }
    }
#endif
