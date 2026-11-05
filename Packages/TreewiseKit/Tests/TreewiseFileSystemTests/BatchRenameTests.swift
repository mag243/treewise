import Foundation
import Testing
import TreewiseCore
import TreewiseFileSystem
import TreewiseTestSupport

/// Applying approved names on a real folder: one undo step, and a clear report when a
/// step fails (ADR 0057).
@Suite struct BatchRenameTests {
    private let directory: TempDirectory
    private let runner = FileOperationRunner()

    init() throws {
        directory = try TempDirectory()
    }

    private func id(_ name: String) -> FileItem.ID { FileItem.ID(directory.url(name).path) }

    private func names() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    private func steps(_ renames: [(String, String)]) throws -> [BatchRenameStep] {
        let batch = renames.map {
            BatchRename(item: id($0.0), folder: FileItem.ID(directory.path), from: $0.0, to: $0.1)
        }
        let all = try names()
        let plan = BatchRenamePlanner.plan(
            batch, namesInFolders: [FileItem.ID(directory.path): all])
        guard case .ready(let steps) = plan else {
            Issue.record("Expected a plan")
            return []
        }
        return steps
    }

    @Test func renamesEveryItem() async throws {
        try directory.makeFile("a.pdf")
        try directory.makeFile("b.pdf")
        let outcome = await runner.applyBatch(
            try steps([("a.pdf", "A1.pdf"), ("b.pdf", "B1.pdf")]))
        #expect(outcome.failure == nil)
        #expect(outcome.renamed.count == 2)
        #expect(try names() == ["A1.pdf", "B1.pdf"])
    }

    @Test func storesASlashFromFinderAsAColon() async throws {
        try directory.makeFile("a.pdf")
        let outcome = await runner.applyBatch(try steps([("a.pdf", "JK:o:1.pdf")]))
        #expect(outcome.failure == nil)
        #expect(try names() == ["JK:o:1.pdf"])
    }

    @Test func swapsTwoItems() async throws {
        try directory.makeFile("a.pdf", contents: "first")
        try directory.makeFile("b.pdf", contents: "second")
        let outcome = await runner.applyBatch(try steps([("a.pdf", "b.pdf"), ("b.pdf", "a.pdf")]))
        #expect(outcome.failure == nil)
        #expect(try String(contentsOf: directory.url("b.pdf"), encoding: .utf8) == "first")
        #expect(try String(contentsOf: directory.url("a.pdf"), encoding: .utf8) == "second")
    }

    @Test func undoesAllAtOnce() async throws {
        try directory.makeFile("a.pdf", contents: "first")
        try directory.makeFile("b.pdf", contents: "second")
        let outcome = await runner.applyBatch(try steps([("a.pdf", "b.pdf"), ("b.pdf", "c.pdf")]))
        _ = try await runner.undo(outcome.undo)
        #expect(try String(contentsOf: directory.url("a.pdf"), encoding: .utf8) == "first")
        #expect(try String(contentsOf: directory.url("b.pdf"), encoding: .utf8) == "second")
        #expect(try names() == ["a.pdf", "b.pdf"])
    }

    @Test func undoesASwapAtOnce() async throws {
        try directory.makeFile("a.pdf", contents: "first")
        try directory.makeFile("b.pdf", contents: "second")
        let outcome = await runner.applyBatch(try steps([("a.pdf", "b.pdf"), ("b.pdf", "a.pdf")]))
        _ = try await runner.undo(outcome.undo)
        #expect(try String(contentsOf: directory.url("a.pdf"), encoding: .utf8) == "first")
        #expect(try String(contentsOf: directory.url("b.pdf"), encoding: .utf8) == "second")
    }

    @Test func stopsAtAFileThatAppearedMeanwhile() async throws {
        try directory.makeFile("a.pdf")
        try directory.makeFile("b.pdf")
        let planned = try steps([("a.pdf", "A1.pdf"), ("b.pdf", "B1.pdf")])
        try directory.makeFile("B1.pdf")
        let outcome = await runner.applyBatch(planned)
        #expect(outcome.renamed.map(\.item.name) == ["A1.pdf"])
        #expect(outcome.failure?.item == id("b.pdf"))
        #expect(try names() == ["A1.pdf", "B1.pdf", "b.pdf"])
    }

    @Test func undoesWhatWasDoneBeforeAFailure() async throws {
        try directory.makeFile("a.pdf")
        try directory.makeFile("b.pdf")
        let planned = try steps([("a.pdf", "A1.pdf"), ("b.pdf", "B1.pdf")])
        try directory.makeFile("B1.pdf")
        let outcome = await runner.applyBatch(planned)
        _ = try await runner.undo(outcome.undo)
        #expect(try names() == ["B1.pdf", "a.pdf", "b.pdf"])
    }

    @Test func reportsAFileLeftUnderItsTemporaryName() async throws {
        try directory.makeFile("a.pdf")
        try directory.makeFile("b.pdf")
        let planned = try steps([("a.pdf", "b.pdf"), ("b.pdf", "a.pdf")])
        // Removing the swap's other file makes the second step fail.
        try FileManager.default.removeItem(at: directory.url("b.pdf"))
        let outcome = await runner.applyBatch(planned)
        #expect(outcome.failure != nil)
        #expect(outcome.failure?.leftUnderTemporaryName?.hasPrefix(".treewise-rename-") == true)
    }

    @Test func reportsAMissingItem() async throws {
        let planned = [BatchRenameStep(item: id("gone.pdf"), from: "gone.pdf", to: "x.pdf")]
        let outcome = await runner.applyBatch(planned)
        #expect(outcome.failure?.error == .notFound(id("gone.pdf")))
    }
}
