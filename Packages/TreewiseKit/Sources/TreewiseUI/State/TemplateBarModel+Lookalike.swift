import Foundation
import TreewiseCore

/// A missing folder whose name nearly matches a folder this year holds at that place, as
/// `Belastingsdienst` in 2025 and `Belastingdienst` in 2026 (ADR 0139): the bar asks which
/// name to keep instead of offering the folder again.
extension TemplateBarModel {
    /// Two names the bar takes for one folder.
    public struct Lookalike: Hashable, Sendable {
        /// What the year's folder lacks, of which this is one folder.
        public let offer: MissingOffer
        /// The path below the year's folder of the folder that holds both.
        public let place: [String]
        /// The name missing this year.
        public let missingName: String
        /// The name this year holds.
        public let presentName: String
        /// The years whose folders hold each name, in order.
        public let missingYears: [Int]
        public let presentYears: [Int]
        /// The folder with the missing name in the year before, and the one this year.
        public let missingFolder: FileItem
        public let presentFolder: FileItem

        /// Whether the name this year holds comes first, as the one in the most years.
        public var presentFirst: Bool { presentYears.count >= missingYears.count }
    }

    /// The first missing folder of `offer` that nearly matches one its year's folder holds
    /// beside it and the year before does not, unless Add Anyway kept the two apart there.
    public func lookalike(for offer: MissingOffer) async -> Lookalike? {
        let kept = await settings.settings(forFolderAt: offer.folder.id.rawValue)
        let years = await siblingYears(of: offer.folder)
        for path in offer.missing.paths {
            let place = Array(path.dropLast())
            guard let name = path.last,
                let here = await folders(at: place, below: offer.folder.id),
                let before = await folders(at: place, below: offer.yearBefore),
                let missingFolder = before.first(where: { Self.isSame($0.name, name) })
            else { continue }
            let history = await self.history(at: place, in: years)
            let earlier = Set(before.map { ConflictResolver.comparisonKey($0.name) })
            for present in here
            where !earlier.contains(ConflictResolver.comparisonKey(present.name)) {
                let pair = FolderSettings.keptApart(name, present.name, at: place)
                guard kept?.namesKeptApart.contains(pair) != true,
                    NearlySameFolderName.matches(
                        name, present.name, isSpelledCorrectly: isSpelledCorrectly,
                        history: history)
                else { continue }
                return Lookalike(
                    offer: offer, place: place, missingName: missingFolder.name,
                    presentName: present.name,
                    missingYears: history.years(of: name).sorted(),
                    presentYears: history.years(of: present.name).sorted(),
                    missingFolder: missingFolder, presentFolder: present)
            }
        }
        return nil
    }

    /// Add Anyway: from then on the bar takes the two names for two folders in that year's
    /// folder, and offers the missing one as before.
    public func addAnyway(_ lookalike: Lookalike) async {
        let pair = FolderSettings.keptApart(
            lookalike.missingName, lookalike.presentName, at: lookalike.place)
        await change(lookalike.offer.folder.id) { $0.namesKeptApart.insert(pair) }
    }

    /// The year's own folders beside `folder`, its own included, by year.
    private func siblingYears(of folder: FileItem) async -> [(year: Int, id: FileItem.ID)] {
        guard let parent = folder.parentID,
            let items = try? await fileSystem.contents(of: parent)
        else { return [] }
        return items.compactMap { item in
            guard item.kind == .folder, let year = YearFolders.year(named: item.name) else {
                return nil
            }
            return (year, item.id)
        }
    }

    /// The names at `place` in each of `years`.
    private func history(at place: [String], in years: [(year: Int, id: FileItem.ID)]) async
        -> FolderNameHistory
    {
        var names: [Int: [String]] = [:]
        for (year, id) in years {
            if let folders = await folders(at: place, below: id) {
                names[year] = folders.map(\.name)
            }
        }
        return FolderNameHistory(names)
    }

    /// The folders in the folder at `place` below `root`, its names compared as the file
    /// system compares them, or nil when there is none.
    private func folders(at place: [String], below root: FileItem.ID) async -> [FileItem]? {
        var folder = root
        for name in place {
            guard let items = try? await fileSystem.contents(of: folder),
                let next = items.first(where: { $0.kind == .folder && Self.isSame($0.name, name) })
            else { return nil }
            folder = next.id
        }
        return (try? await fileSystem.contents(of: folder))?.filter { $0.kind == .folder }
    }

    private static func isSame(_ one: String, _ other: String) -> Bool {
        ConflictResolver.comparisonKey(one) == ConflictResolver.comparisonKey(other)
    }
}
