import Testing
import TreewiseCore

/// Planning approved renames so conflicts show before anything changes (ADR 0057).
@Suite struct BatchRenamePlannerTests {
    private func rename(_ from: String, _ to: String, folder: FileItem.ID = "/f") -> BatchRename {
        BatchRename(
            item: FileItem.ID(stringLiteral: "\(folder)/\(from)"), folder: folder, from: from,
            to: to)
    }

    private func steps(_ plan: BatchRenamePlan) -> [String] {
        guard case .ready(let steps) = plan else { return [] }
        return steps.map { "\($0.from)>\($0.to)" }
    }

    private func conflicts(_ plan: BatchRenamePlan) -> [BatchRenameConflict] {
        guard case .conflicts(let conflicts) = plan else { return [] }
        return conflicts
    }

    @Test func plansAFreeRename() {
        let plan = BatchRenamePlanner.plan([rename("a", "b")], namesInFolders: ["/f": ["a"]])
        #expect(steps(plan) == ["a>b"])
    }

    @Test func reportsANameTakenInTheFolder() {
        let plan = BatchRenamePlanner.plan([rename("a", "b")], namesInFolders: ["/f": ["a", "b"]])
        #expect(conflicts(plan) == [.init(item: "/f/a", kind: .nameTaken("b"))])
    }

    @Test func comparesNamesAsTheFileSystemDoes() {
        let composed = "caf\u{E9}"
        let decomposed = "cafe\u{301}"
        let plan = BatchRenamePlanner.plan(
            [rename("a", decomposed.uppercased())], namesInFolders: ["/f": ["a", composed]])
        #expect(conflicts(plan).count == 1)
    }

    @Test func reportsBothItemsThatWantOneName() {
        let plan = BatchRenamePlanner.plan(
            [rename("a", "x"), rename("b", "X")], namesInFolders: ["/f": ["a", "b"]])
        #expect(
            conflicts(plan) == [
                .init(item: "/f/a", kind: .duplicateInBatch),
                .init(item: "/f/b", kind: .duplicateInBatch),
            ])
    }

    @Test func allowsTheSameNameInDifferentFolders() {
        let plan = BatchRenamePlanner.plan(
            [rename("a", "x", folder: "/f"), rename("a", "x", folder: "/g")],
            namesInFolders: ["/f": ["a"], "/g": ["a"]])
        #expect(steps(plan) == ["a>x", "a>x"])
    }

    @Test func allowsACaseOnlyRename() {
        let plan = BatchRenamePlanner.plan([rename("a", "A")], namesInFolders: ["/f": ["a"]])
        #expect(steps(plan) == ["a>A"])
    }

    @Test func aNameFreedByTheBatchCanBeTaken() {
        let plan = BatchRenamePlanner.plan(
            [rename("a", "b"), rename("b", "c")], namesInFolders: ["/f": ["a", "b"]])
        #expect(steps(plan) == ["b>c", "a>b"])
    }

    @Test func ordersALongChainFromItsFreeEnd() {
        let plan = BatchRenamePlanner.plan(
            [rename("a", "b"), rename("b", "c"), rename("c", "d")],
            namesInFolders: ["/f": ["a", "b", "c"]])
        #expect(steps(plan) == ["c>d", "b>c", "a>b"])
    }

    @Test func swapsThroughATemporaryName() throws {
        let plan = BatchRenamePlanner.plan(
            [rename("a", "b"), rename("b", "a")], namesInFolders: ["/f": ["a", "b"]])
        let steps = steps(plan)
        try #require(steps.count == 3)
        let temporary = try #require(steps[0].split(separator: ">").last)
        #expect(steps[0].hasPrefix("a>"))
        #expect(steps[1] == "b>a")
        #expect(steps[2] == "\(temporary)>b")
    }

    @Test func aTemporaryNameAvoidsEveryNameInTheFolder() throws {
        let first = BatchRenamePlanner.plan(
            [rename("a", "b"), rename("b", "a")], namesInFolders: ["/f": ["a", "b"]])
        let temporary = try #require(steps(first)[0].split(separator: ">").last.map(String.init))
        let second = BatchRenamePlanner.plan(
            [rename("a", "b"), rename("b", "a")], namesInFolders: ["/f": ["a", "b", temporary]])
        #expect(!steps(second)[0].hasSuffix(">\(temporary)"))
    }

    @Test func handlesAThreeItemCycle() {
        let plan = BatchRenamePlanner.plan(
            [rename("a", "b"), rename("b", "c"), rename("c", "a")],
            namesInFolders: ["/f": ["a", "b", "c"]])
        let steps = steps(plan)
        #expect(steps.count == 4)
        #expect(Array(steps[1...2]) == ["c>a", "b>c"])
    }

    @Test func aPlanWithConflictsHasNoSteps() {
        let plan = BatchRenamePlanner.plan(
            [rename("a", "free"), rename("b", "taken")],
            namesInFolders: ["/f": ["a", "b", "taken"]])
        #expect(steps(plan).isEmpty)
        #expect(conflicts(plan).count == 1)
    }

    @Test func survivesNamesThatCompareAsOneOnACaseSensitiveVolume() {
        let plan = BatchRenamePlanner.plan(
            [rename("a", "b"), rename("b", "a"), rename("A", "q")],
            namesInFolders: ["/f": ["a", "A", "b"]])
        guard case .ready(let steps) = plan else {
            Issue.record("Expected a plan")
            return
        }
        #expect(Set(steps.map(\.item)).count == 3)
    }

    @Test func anEmptyBatchIsReady() {
        #expect(BatchRenamePlanner.plan([], namesInFolders: [:]) == .ready([]))
    }
}
