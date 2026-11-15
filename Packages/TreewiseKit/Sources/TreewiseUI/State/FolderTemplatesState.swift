import Observation
import TreewiseCore

/// What every window shares of folder structure templates and changes while Treewise
/// runs (ADR 0091, ADR 0099): the structure Copy Folder Structure copied, and the add-on
/// that makes folder structures with whether it may work now. Observable, so a view that
/// shows it follows a change, such as a licence entered in Settings.
@MainActor
@Observable
public final class FolderTemplatesState {
    /// The structure Copy Folder Structure copied, for Paste Folder Structure… in any window
    /// (ADR 0099); nil until a folder's structure is copied.
    public var copiedStructure: FolderTree?
    /// The id of the add-on that makes folder structures, when the build carries one.
    public private(set) var addOnID: String?
    /// Whether that add-on may work, with a licence or in its trial (ADR 0088).
    public private(set) var mayWork = false
    /// The name of each add-on the build carries, by its id, for the name settings a
    /// template keeps (ADR 0101).
    public private(set) var addOnNames: [String: String] = [:]

    public init() {}

    /// Whether the build carries the add-on and it may work now.
    public var addOnMayWork: Bool { addOnID != nil && mayWork }

    /// Keeps what was found of the add-ons.
    public func found(addOnID: String?, mayWork: Bool, addOnNames: [String: String]) {
        self.addOnID = addOnID
        self.mayWork = mayWork
        self.addOnNames = addOnNames
    }
}
