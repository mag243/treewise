import Foundation
import Testing
import TreewiseCore
import TreewiseFolderPatternModule
import TreewiseModuleInterface

extension Tag {
    /// Measurements of how long a module takes, which set no limit yet.
    @Tag static var benchmark: Tag
}

/// How long the free module takes for a folder of 100 files, in this process and without
/// the service between: the time it adds to what the overview spends (M7, speed targets).
/// Runs only with TREEWISE_BENCHMARK=1 (`tools/build.sh benchmark`); each measurement is
/// an attachment.
@Suite(
    .tags(.benchmark),
    .enabled(
        if: ProcessInfo.processInfo.environment["TREEWISE_BENCHMARK"] == "1",
        "set TREEWISE_BENCHMARK=1 (tools/build.sh benchmark)"))
struct FolderPatternModuleBenchmarks {
    /// The files of the folder, of which most follow its pattern.
    private static let fileCount = 100
    private static let fittingCount = 60
    /// How often each measurement runs; the median counts.
    private static let runs = 11
    private static let folder = "Holiday"

    private let module = FolderPatternModule()

    /// Most names dated with the folder's name and a place, the rest as a camera names them.
    private static let names: [String] = (0..<fileCount).map { index in
        let day = index % 28 + 1
        return index < fittingCount
            ? "2026.08.\(day < 10 ? "0" : "")\(day) Holiday - Place \(index).heic"
            : "IMG_\(4000 + index).heic"
    }

    @Test func recognizingTheFoldersPattern() {
        let median = Self.median {
            _ = module.derivedTemplates(
                fromNames: Self.names, folderName: Self.folder, licence: .none)
        }
        Self.record("Free module: recognizing a pattern in \(Self.fileCount) names", median)
    }

    @Test func valuesForEveryFile() async throws {
        let requests = Self.names.map { name in
            NameRequest(
                id: name, name: name, contentType: "public.heic", byteCount: nil,
                created: nil, modified: nil, suggestedDate: nil,
                siblingNames: Self.names.filter { $0 != name }, content: ModuleContent(),
                folderName: Self.folder)
        }
        var durations: [Duration] = []
        for _ in 0..<Self.runs {
            let start = ContinuousClock.now
            for request in requests { _ = try await module.fieldValues(for: request) }
            durations.append(ContinuousClock.now - start)
        }
        Self.record(
            "Free module: values for \(Self.fileCount) files", durations.sorted()[Self.runs / 2])
    }

    private static func median(_ body: () -> Void) -> Duration {
        let durations = (0..<runs).map { _ in ContinuousClock().measure(body) }
        return durations.sorted()[runs / 2]
    }

    private static func record(_ what: String, _ duration: Duration) {
        let milliseconds = duration.formatted(
            .units(allowed: [.milliseconds], fractionalPart: .show(length: 2)))
        Attachment.record("\(what): \(milliseconds) (median of \(runs))", named: "\(what).txt")
    }
}
