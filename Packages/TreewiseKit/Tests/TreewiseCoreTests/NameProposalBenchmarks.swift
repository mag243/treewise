import Foundation
import Testing
import TreewiseCore

extension Tag {
    /// Measurements of how long naming takes for a large folder.
    @Tag static var namingBenchmark: Tag
}

/// How long proposing names takes in a folder of 1,000 files, as the review does it for
/// every file and module. Runs only with TREEWISE_BENCHMARK=1 (`tools/build.sh benchmark`);
/// each measurement is an attachment.
@Suite(
    .tags(.namingBenchmark),
    .enabled(
        if: ProcessInfo.processInfo.environment["TREEWISE_BENCHMARK"] == "1",
        "set TREEWISE_BENCHMARK=1 (tools/build.sh benchmark)"))
struct NameProposalBenchmarks {
    private static let fileCount = 1_000
    /// The files proposed for in one measurement; each matches against every sibling.
    private static let proposedCount = 50
    private static let runs = 5
    private static let fields: [NameTemplate.Field] =
        [.init(name: "date", kind: .date), .init(name: "text", kind: .text)]
        + NameTemplate.Field.suppliedByTreewise

    private static let names: [String] = (0..<fileCount).map { index in
        "2026-\(String(format: "%02d", index % 12 + 1))-01 Invoice \(index).pdf"
    }

    /// Names as a scanner gives them, which the pattern does not fit, so each is also
    /// tried for a name that nearly fits.
    private static let scans: [String] = (0..<fileCount).map { "Scan \($0).pdf" }

    /// Names of a series, which every proposal reads to find the next number.
    private static let series: [String] = (0..<fileCount).map {
        "Invoice \(String(format: "%04d", $0)).pdf"
    }

    @Test func proposingNamesInALargeFolder() throws {
        try measure("{date} {text}", Self.names, "names that fit")
    }

    @Test func proposingNamesForNamesThatDoNotFit() throws {
        try measure("{date} {text}", Self.scans, "names that do not fit")
    }

    @Test func proposingTheNextNumberOfASeries() throws {
        try measure("Invoice {seq}", Self.series, "names of a series")
    }

    @Test func proposingNamesFromAChoiceOfParts() throws {
        try measure("{date|text} Invoice {seq}", Self.series, "names for a choice of parts")
    }

    /// Proposes as the review does: the folder's names are split once for all its files.
    private func measure(_ pattern: String, _ names: [String], _ kind: String) throws {
        let template = try NameTemplate.parse(pattern, fields: Self.fields).get()
        let durations = (0..<Self.runs).map { _ in
            ContinuousClock().measure {
                let folderNames = FolderNames(names)
                for name in names.prefix(Self.proposedCount) {
                    _ = NameProposal.make(
                        from: [
                            ["text": .text("Invoice"), "date": .date(year: 2026, month: 3, day: 1)]
                        ],
                        template: template, moduleID: "m", folderName: "Invoices",
                        suggestedDate: nil, folderNames: folderNames, currentName: name)
                }
            }
        }
        let median = durations.sorted()[Self.runs / 2]
        let milliseconds = median.formatted(
            .units(allowed: [.milliseconds], fractionalPart: .show(length: 2)))
        let what = "Naming: proposals for \(Self.proposedCount) of \(Self.fileCount) \(kind)"
        Attachment.record("\(what): \(milliseconds) (median of \(Self.runs))", named: "\(what).txt")
    }
}
