/// The ids add-ons had before they were renamed (ADR 0140), and the ids they have now.
/// This is the only place that knows the former ids: what is read with one, from
/// Treewise's own storage, a template file or a licence key, holds the current id.
/// A former id is never given to anything else.
public enum AddOnIDs {
    /// Each former id, with the id the add-on has now.
    public static let former: [String: String] = [
        "me.m-domain.treewise.folder-pattern": "me.m-domain.treewise.file-name-patterns",
        "me.m-domain.treewise.folder-pattern-advanced":
            "me.m-domain.treewise.file-name-patterns-advanced",
    ]

    /// The id an add-on has now for `id`: its current one for a former id, else `id`.
    public static func current(_ id: String) -> String {
        former[id] ?? id
    }

    /// The ids the add-on with the id `id` had before, as a licence key may name it.
    public static func formerIDs(of id: String) -> Set<String> {
        Set(former.filter { $0.value == id }.keys)
    }

    /// Whether `text`, as a stored file, holds a former id, so it is to be saved again.
    public static func holdsFormerID(_ text: String) -> Bool {
        former.keys.contains { text.contains("\"\($0)\"") }
    }

    /// Hands what was kept for each former id over to its current id, with `handOver`.
    static func convert(_ handOver: (_ replaced: String, _ replacing: String) -> Void) {
        for (old, new) in former.sorted(by: { $0.key < $1.key }) { handOver(old, new) }
    }
}
