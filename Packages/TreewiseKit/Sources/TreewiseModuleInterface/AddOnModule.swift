import TreewiseCore

/// What an add-on does (ADR 0091).
public enum AddOnKind: String, Hashable, Sendable, Codable {
    /// It proposes names for files and folders (ADR 0057).
    case names
    /// It makes the template of a folder's structure, and the folders a template makes.
    case folderStructure
}

/// What every add-on is, whatever it does: its description and its licence (ADR 0057,
/// ADR 0071). It gets no way to reach a file, and on the Mac it runs in a service without
/// access to the network or the user's files.
///
/// This interface is internal to Treewise: it has no stability promise, and the official app
/// loads no third-party add-ons (ADR 0055).
public protocol AddOnModule: Sendable {
    /// A stable id.
    var id: String { get }
    /// What this add-on is, for the app to show and to know without running it.
    var description: NameModuleDescription { get }
    /// What its licence lets it do, or nil when it needs no licence (ADR 0071).
    func licenceState(licence: LicenceContext) -> ModuleLicenceState?
}

extension AddOnModule {
    /// The id, from the description.
    public var id: String { description.id }

    /// An add-on needs no licence unless it says so.
    public func licenceState(licence: LicenceContext) -> ModuleLicenceState? {
        nil
    }
}

/// An add-on that makes folder structures (ADR 0091). It sees folder names only and makes
/// nothing itself: Treewise checks what it returns and makes the folders. It keeps no state
/// between questions.
public protocol FolderStructureModule: AddOnModule {
    /// The template of a folder's tree, as saving it as a template keeps it, or nil while its
    /// licence lets it do nothing.
    func template(from tree: FolderTree, licence: LicenceContext) -> FolderTree?
    /// The folders `template` makes with its fields filled in from `values` (ADR 0096), or
    /// nil while its licence lets it do nothing or a field has no value.
    func folders(
        making template: FolderTree, values: FolderTemplateValues, licence: LicenceContext
    ) -> FolderTree?
}
