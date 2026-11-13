import Foundation

/// A folder kept per year, for an add-on that reads the year before (ADR 0090): the year of
/// the folder, from its path, and the names in the same folder a year before, of the files
/// the add-on handles; none when there is no such folder.
public struct FolderYears: Hashable, Sendable, Codable {
    /// The year of the folder.
    public let year: Int
    /// The names in the same folder a year before.
    public let namesYearBefore: [String]

    /// Creates the years of a folder.
    public init(year: Int, namesYearBefore: [String]) {
        self.year = year
        self.namesYearBefore = namesYearBefore
    }
}
