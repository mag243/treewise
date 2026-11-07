/// What the user chose for the add-ons across the app, in Settings (ADR 0070): which are
/// turned off everywhere, which are on in a folder reviewed for the first time, and the
/// order for folders without one of their own. Add-ons are named by their ids; a
/// catalog is the ids the app has, in its own order.
///
/// Invariant, for any catalog: at least one add-on is on, and at least one of those is on
/// in new folders.
public struct AddOnPreferences: Hashable, Sendable, Codable {
    /// The add-ons offered in no folder.
    private var turnedOff: Set<String> = []
    /// The add-ons on in new folders; nil until the user chooses, when only the default
    /// module is.
    private var onInNewFolders: Set<String>?
    /// The user's default order, those turned off included; empty until the user drags.
    private var order: [String] = []

    /// Preferences as a new user has them.
    public init() {}

    /// Whether an add-on is offered at all.
    public func isOn(_ id: String) -> Bool {
        !turnedOff.contains(id)
    }

    /// The add-ons of `catalog` that are offered, in the default order.
    public func available(_ catalog: [String]) -> [String] {
        ordered(catalog).filter(isOn)
    }

    /// Turns an add-on on or off for every folder; the last one that is on stays on.
    public mutating func setOn(_ id: String, on: Bool, catalog: [String]) {
        if on {
            turnedOff.remove(id)
        } else if available(catalog).contains(where: { $0 != id }) {
            turnedOff.insert(id)
        }
    }

    /// Whether an add-on is on in a folder reviewed for the first time.
    public func isOnInNewFolders(_ id: String, defaultID: String) -> Bool {
        onInNewFolders?.contains(id) ?? (id == defaultID)
    }

    /// Chooses whether an add-on is on in new folders; one that is offered stays on there.
    public mutating func setOnInNewFolders(
        _ id: String, on: Bool, catalog: [String], defaultID: String
    ) {
        var chosen = Set(catalog.filter { isOnInNewFolders($0, defaultID: defaultID) })
        if on { chosen.insert(id) } else { chosen.remove(id) }
        guard available(catalog).contains(where: chosen.contains) else { return }
        onInNewFolders = chosen
    }

    /// The add-ons of `catalog` in the default order: those the user ordered first, then
    /// the rest in the catalog's order, so a new add-on comes last.
    public func ordered(_ catalog: [String]) -> [String] {
        order.filter(catalog.contains) + catalog.filter { !order.contains($0) }
    }

    /// Moves an add-on to a place in the default order.
    public mutating func move(_ id: String, to index: Int, catalog: [String]) {
        var all = ordered(catalog)
        guard let from = all.firstIndex(of: id) else { return }
        all.remove(at: from)
        all.insert(id, at: min(max(0, index), all.count))
        order = all
    }

    /// Gives the choices for a module to the module that replaces it (ADR 0067): whether
    /// it is on, whether it is on in new folders, and its place in the default order.
    public mutating func handOver(from replaced: String, to replacing: String) {
        if turnedOff.remove(replaced) != nil { turnedOff.insert(replacing) }
        if onInNewFolders?.remove(replaced) != nil { onInNewFolders?.insert(replacing) }
        order = order.map { $0 == replaced ? replacing : $0 }
    }

    /// The settings of a folder reviewed for the first time: the add-ons on in new
    /// folders that are offered, in the default order, or else the first that is offered.
    public func newFolder(catalog: [String], defaultID: String) -> FolderSettings {
        let offered = available(catalog)
        let chosen = offered.filter { isOnInNewFolders($0, defaultID: defaultID) }
        return FolderSettings(
            enabledModules: chosen.isEmpty ? Array(offered.prefix(1)) : chosen, templates: [:])
    }
}
