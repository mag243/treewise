import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// The line of the progress panel (ADR 0021).
@Suite struct ProgressTextTests {
    private let locale = Locale(identifier: "en_GB")

    @Test func namesTheFileAndTheBytesCopied() {
        let progress = OperationProgress(
            completedBytes: 84_000_000, totalBytes: 6_000_000_000, currentName: "Clip_0042.mov")
        #expect(
            ProgressText.text(for: progress, locale: locale)
                == "Copying “Clip_0042.mov” — 84 MB of 6 GB")
    }

    @Test func leavesTheNameOutBetweenItems() {
        let progress = OperationProgress(completedBytes: 84_000_000, totalBytes: 6_000_000_000)
        #expect(ProgressText.text(for: progress, locale: locale) == "Copying — 84 MB of 6 GB")
    }

    @Test func saysWhenTheTransferIsPaused() {
        let progress = OperationProgress(
            completedBytes: 84_000_000, totalBytes: 6_000_000_000, currentName: "Clip_0042.mov")
        #expect(
            ProgressText.text(for: progress, isPaused: true, locale: locale)
                == "Paused — 84 MB of 6 GB")
    }

    @Test func countsTheEntriesOfAnArchive() {
        let extracting = OperationProgress(
            completedBytes: 3, totalBytes: 6, currentName: "a.txt", kind: .extracting)
        #expect(
            ProgressText.text(for: extracting, locale: locale)
                == "Extracting “a.txt” — 3 of 6 items")
        let compressing = OperationProgress(
            completedBytes: 3, totalBytes: 6, currentName: "a.txt", kind: .compressing)
        #expect(
            ProgressText.text(for: compressing, locale: locale)
                == "Compressing “a.txt” — 3 of 6 items")
    }

    @Test func saysItIsStartingBeforeTheEntriesAreCounted() {
        let progress = OperationProgress(completedBytes: 0, totalBytes: 0, kind: .extracting)
        #expect(ProgressText.text(for: progress, locale: locale) == "Extracting…")
        #expect(progress.fraction == 0)
    }

    @Test func aPausedArchiveCountsItsEntries() {
        let progress = OperationProgress(completedBytes: 3, totalBytes: 6, kind: .compressing)
        #expect(
            ProgressText.text(for: progress, isPaused: true, locale: locale)
                == "Paused — 3 of 6 items")
    }
}
