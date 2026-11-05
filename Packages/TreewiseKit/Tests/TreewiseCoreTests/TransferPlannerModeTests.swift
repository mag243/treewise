import Testing
import TreewiseCore

/// The mode table of PLAN.md §4.1 and ADR 0003.
@Suite struct TransferPlannerModeTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let target: FileItem.ID
        let modifiers: DropModifiers
        let expected: TransferMode
        var testDescription: String { "onto \(target) with \(modifiers) → \(expected)" }
    }

    /// `Notes.md` lives on Macintosh HD; Projects is on the same volume,
    /// Backups on the external drive.
    @Test(arguments: [
        Case(target: "projects", modifiers: [], expected: .move),
        Case(target: "backups", modifiers: [], expected: .copy),
        Case(target: "projects", modifiers: .option, expected: .copy),
        Case(target: "backups", modifiers: .option, expected: .copy),
        Case(target: "projects", modifiers: .command, expected: .move),
        Case(target: "backups", modifiers: .command, expected: .move),
        Case(target: "projects", modifiers: [.option, .command], expected: .copy),
        Case(target: "backups", modifiers: [.option, .command], expected: .copy),
    ])
    func modeFollowsVolumeAndModifiers(_ testCase: Case) {
        #expect(planDrag(["doc2"], onto: testCase.target, testCase.modifiers) == testCase.expected)
    }

    @Test func copiesWhenTheItemsComeFromDifferentVolumes() {
        #expect(planDrag(["d2", "v1"], onto: "documents") == .copy)
    }

    @Test func copiesOntoACloudLocation() {
        #expect(planDrag(["doc2"], onto: "icloud") == .copy)
    }

    @Test func copiesOntoAnotherVolumeItself() {
        #expect(planDrag(["doc2"], onto: "usb") == .copy)
    }
}
