/// An order the user chose of ids from a catalog that changes, as of add-ons (ADR 0065,
/// ADR 0067), shared by the default order and each folder's.
enum UserOrder {
    /// The ids of `catalog` in `order`: those ordered first, then the rest in the catalog's
    /// order, so one new to the catalog comes last.
    static func ordered(_ order: [String], _ catalog: [String]) -> [String] {
        let ordered = Set(order)
        return order.filter(catalog.contains) + catalog.filter { !ordered.contains($0) }
    }

    /// The order of `catalog` with `id` moved to `index`, or nil when `id` is not in it.
    static func moving(_ id: String, to index: Int, in order: [String], catalog: [String])
        -> [String]?
    {
        var all = ordered(order, catalog)
        guard let from = all.firstIndex(of: id) else { return nil }
        all.remove(at: from)
        all.insert(id, at: min(max(0, index), all.count))
        return all
    }

    /// `ids` with `replaced` written as `replacing`, each id once, at its first place: one
    /// that replaces another may already be there, as after it was dragged.
    static func replacing(_ replaced: String, with replacing: String, in ids: [String])
        -> [String]
    {
        var seen: Set<String> = []
        return ids.map { $0 == replaced ? replacing : $0 }.filter { seen.insert($0).inserted }
    }
}
