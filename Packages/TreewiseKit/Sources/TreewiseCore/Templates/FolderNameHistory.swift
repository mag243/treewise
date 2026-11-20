/// The names of the folders at one place in each year's folder, as `Tax` and `Bank` below
/// `2025`, `2026`, …, which tell whether two names are one folder (ADR 0139). Names
/// compare as the file system compares them.
public struct FolderNameHistory: Sendable {
    /// The compared form of each name, with the years that hold it.
    private let yearsByKey: [String: Set<Int>]

    /// The history of `namesByYear`: the names of the folders at the place, by year.
    public init(_ namesByYear: [Int: [String]] = [:]) {
        var years: [String: Set<Int>] = [:]
        for (year, names) in namesByYear {
            for name in names {
                years[ConflictResolver.comparisonKey(name), default: []].insert(year)
            }
        }
        yearsByKey = years
    }

    /// The years that hold a folder named `name`.
    public func years(of name: String) -> Set<Int> {
        yearsByKey[ConflictResolver.comparisonKey(name)] ?? []
    }

    /// Whether a year holds both names: then they are two folders on purpose.
    func areSideBySide(_ one: String, _ other: String) -> Bool {
        !years(of: one).isDisjoint(with: years(of: other))
    }

    /// Whether both names are there, never side by side, one in more years than the other:
    /// then the rarer is likely the other written differently.
    func takesOneForTheOther(_ one: String, _ other: String) -> Bool {
        let (first, second) = (years(of: one), years(of: other))
        return !first.isEmpty && !second.isEmpty && first.isDisjoint(with: second)
            && first.count != second.count
    }
}
