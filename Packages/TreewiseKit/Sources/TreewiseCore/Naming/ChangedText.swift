/// Where one name differs from another, so stepping to another option can select what
/// changed (ADR 0064).
public enum ChangedText {
    /// The part of `new` between what it shares with `old` at the start and at the end.
    ///
    /// Postcondition: the range lies in `new`, and is empty when the names are the same.
    public static func range(from old: String, to new: String) -> Range<String.Index> {
        let start = zip(old, new).prefix { $0 == $1 }.count
        let room = min(old.count, new.count) - start
        let end = zip(old.reversed(), new.reversed()).prefix(room).prefix { $0 == $1 }.count
        let lower = new.index(new.startIndex, offsetBy: start)
        let upper = new.index(new.endIndex, offsetBy: -end)
        return lower..<upper
    }
}
