import Foundation
import Synchronization
import Testing
import TreewiseCore
import TreewiseTestSupport

@testable import TreewiseFileSystem

/// The check of a copy before a move removes its source (ADR 0004), on one volume, with
/// the copy's footprint stood in for so that a mismatch can be made.
@Suite struct FileCopierTests {
    private static let noProgress: FileCopyProgress = { _, _ in }

    private func names(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    private func report(in directory: TempDirectory) throws -> URL {
        try directory.makeFolder("from/Report")
        try directory.makeFile("from/Report/a.txt", contents: "hello")
        try directory.makeFile("from/Report/b.txt", contents: "world")
        try directory.makeFolder("to")
        return directory.url("from/Report")
    }

    @Test func leavesNothingBehindWhenTheCopyDoesNotMatch() throws {
        let directory = try TempDirectory()
        let source = try report(in: directory)
        #expect(throws: FileSystemError.verificationFailed(FileItem.ID(source.path))) {
            try FileCopier.copyCompletely(
                source, into: directory.url("to"), as: "Report", onFile: Self.noProgress,
                control: TransferControl(),
                verifying: { url in
                    url == source
                        ? FileCopier.footprint(of: url) : FileCopier.Footprint(size: 0, items: 0)
                })
        }
        #expect(try names(in: directory.url("to")).isEmpty)
        #expect(try names(in: source) == ["a.txt", "b.txt"])
    }

    /// A file that lands in the source while it is copied is not in the copy, and the
    /// source must then stay, as removing it would lose that file.
    @Test func refusesACopyOfASourceThatGrewWhileCopied() throws {
        let directory = try TempDirectory()
        let source = try report(in: directory)
        let grown = Mutex(false)
        let growing: FileCopyProgress = { _, _ in
            guard !grown.withLock({ $0 }) else { return }
            grown.withLock { $0 = true }
            try? Data("late".utf8).write(to: source.appendingPathComponent("late.txt"))
        }
        #expect(throws: FileSystemError.verificationFailed(FileItem.ID(source.path))) {
            try FileCopier.copyCompletely(
                source, into: directory.url("to"), as: "Report", onFile: growing,
                control: TransferControl(), verifying: FileCopier.footprint(of:))
        }
        #expect(try names(in: directory.url("to")).isEmpty)
    }

    @Test func checksTheCopyBeforeItHasItsName() throws {
        let directory = try TempDirectory()
        let source = try report(in: directory)
        let checked = Mutex<[String]>([])
        _ = try FileCopier.copyCompletely(
            source, into: directory.url("to"), as: "Report", onFile: Self.noProgress,
            control: TransferControl(),
            verifying: { copy in
                if copy != source { checked.withLock { $0.append(copy.lastPathComponent) } }
                return FileCopier.footprint(of: copy)
            })
        let names = checked.withLock { $0 }
        #expect(names.count == 1)
        #expect(names.allSatisfy { $0.hasPrefix(FileCopier.partialPrefix) })
    }

    @Test func givesAMatchingCopyItsName() throws {
        let directory = try TempDirectory()
        let source = try report(in: directory)
        let copy = try FileCopier.copyCompletely(
            source, into: directory.url("to"), as: "Report", onFile: Self.noProgress,
            control: TransferControl(), verifying: FileCopier.footprint(of:))
        #expect(copy.lastPathComponent == "Report")
        #expect(try names(in: copy) == ["a.txt", "b.txt"])
    }
}
