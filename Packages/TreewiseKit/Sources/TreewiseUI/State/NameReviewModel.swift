import Foundation
import Observation
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface
import os

/// What the review overview needs from outside (ADR 0057).
public struct NameReviewDependencies: Sendable {
    /// Builds what a module may see of an item: a file's facts and declared contents.
    public typealias MakeRequest =
        @Sendable (FileItem, [FileItem], Set<ModuleContentKind>) async -> NameRequest
    /// Saves a pattern under a name; returns why not, or nil when it did (ADR 0068).
    public typealias SavePattern = @MainActor @Sendable (String, String) -> SavedPatterns.Problem?
    /// Gives a saved pattern another text.
    public typealias ChangeSavedPattern = @MainActor @Sendable (SavedPattern.ID, String) -> Void

    let operations: any FileOperating
    let host: any NameModuleHosting
    let store: any FolderSettingsStoring
    /// The user's pattern for a folder without one.
    let defaultPattern: String
    /// What Approve All does with a name that holds personal data.
    let personalDataInNames: PersonalDataInNames
    let makeRequest: MakeRequest
    /// What Settings decides for the add-ons across the app (ADR 0070).
    let addOns: AddOnPreferences
    /// The licence keys and the trials' dates, for paid modules (ADR 0071, ADR 0088).
    let licence: @MainActor @Sendable () -> LicenceContext
    /// The user's saved patterns (ADR 0068).
    let savedPatterns: @MainActor @Sendable () -> SavedPatterns
    let savePattern: SavePattern
    /// Gives a saved pattern another text.
    let changeSavedPattern: ChangeSavedPattern

    /// Creates the dependencies.
    public init(
        operations: any FileOperating, host: any NameModuleHosting,
        store: any FolderSettingsStoring, defaultPattern: String,
        personalDataInNames: PersonalDataInNames = .leaveOutOfApproveAll,
        addOns: AddOnPreferences = AddOnPreferences(),
        licence: @escaping @MainActor @Sendable () -> LicenceContext = { .none },
        savedPatterns: @escaping @MainActor @Sendable () -> SavedPatterns = { .examples() },
        savePattern: @escaping SavePattern = { _, _ in nil },
        changeSavedPattern: @escaping ChangeSavedPattern = { _, _ in },
        makeRequest: @escaping MakeRequest
    ) {
        self.operations = operations
        self.host = host
        self.store = store
        self.defaultPattern = defaultPattern
        self.personalDataInNames = personalDataInNames
        self.makeRequest = makeRequest
        self.addOns = addOns
        self.licence = licence
        self.savedPatterns = savedPatterns
        self.savePattern = savePattern
        self.changeSavedPattern = changeSavedPattern
    }
}

/// A module as the overview shows it.
public struct NameReviewModule: Identifiable, Hashable, Sendable {
    /// Where a module's template comes from.
    public enum Origin: Hashable, Sendable {
        /// Recognized in the folder's names.
        case derived
        /// The module's default.
        case moduleDefault
        /// Changed by the user.
        case user
        /// None recognized, so the default module proposes nothing until the user picks one.
        case notRecognized
        /// None recognized, and the user's own default is used because files were selected.
        case usersDefault
    }

    /// What the module is.
    public let description: NameModuleDescription
    /// Whether it is on for this folder.
    public internal(set) var isOn: Bool
    /// Its template as last typed, usable or not.
    public internal(set) var templateText: String
    /// Where its template comes from.
    public internal(set) var origin: Origin
    /// Why the typed template cannot be used; the last usable one stays in force.
    public internal(set) var templateProblem: NameTemplate.Problem?
    /// The template in force.
    var template: NameTemplate?
    /// The template it had before the user changed it, if it had one.
    var recognized: String?
    /// What its licence lets it do, for a paid module; an unlicensed one is off and cannot
    /// be turned on (ADR 0071).
    public internal(set) var licence: ModuleLicenceState?
    /// The templates it recognized in the folder, the best first, to pick from (ADR 0067).
    public internal(set) var candidates: [PatternCandidate] = []

    /// The module's id.
    public var id: String { description.id }
}

/// The state of the review overview: proposals for a folder or a selection, the user's
/// choices, and applying them (ADR 0057).
@MainActor
@Observable
public final class NameReviewModel {
    static let logger = Logger(subsystem: "me.m-domain.treewise", category: "NameReview")

    /// The folder under review.
    public let folder: FileItem
    /// What the user opened the review for.
    public let scope: NameReviewRules.Scope
    /// The review of every item.
    public internal(set) var session: NameProposalSession?
    /// All modules, in their order.
    public internal(set) var modules: [NameReviewModule] = []
    /// The selected row.
    public var selectedID: FileItem.ID?
    /// How many files are still being read.
    public internal(set) var readingCount = 0
    /// Whether this folder is reviewed for the first time.
    public internal(set) var isFirstReview = false
    /// Whether a module failed to answer.
    public internal(set) var moduleFailed = false
    /// What stands in the way of each name shown now.
    public internal(set) var conflicts: [FileItem.ID: BatchRenameConflict.Kind] = [:]
    /// What applying did, once it ran.
    public internal(set) var outcome: BatchRenameOutcome?
    /// What each item's plan says.
    var plans: [FileItem.ID: NameReviewRules.Plan] = [:]
    /// The folder's settings.
    var settings = FolderSettings(enabledModules: [], templates: [:])
    /// The keys and the trial's dates this review asks paid modules with (ADR 0071).
    var licence = LicenceContext.none
    /// What each paid module's licence lets it do.
    var licenceStates: [String: ModuleLicenceState] = [:]
    /// The modules that may work in this review: offered, on in Settings and licensed or
    /// in their trial.
    var working: [String] = []
    /// What a folder seen for the first time would have on, for when none of its own may work.
    var freshEnabled: [String] = []

    /// The modules on in this folder that may work. The folder's settings keep what was
    /// chosen for the others, so it comes back when they may work again (ADR 0070, 0071).
    var enabled: [String] {
        let chosen = settings.enabledModules.filter(working.contains)
        return chosen.isEmpty ? freshEnabled : chosen
    }
    /// The folder's items, for the names around a new name and for conflicts.
    var folderItems: [FileItem] = []
    /// The items under review.
    var items: [FileItem] = []
    /// Each item's facts, without contents.
    var facts: [FileItem.ID: NameRequest] = [:]
    /// What modules answered, by item and module.
    var answers: [FileItem.ID: [String: [[String: NameTemplate.Value]]]] = [:]
    /// The asking that is under way.
    var reading: Task<Void, Never>?

    @ObservationIgnored let dependencies: NameReviewDependencies
    @ObservationIgnored private let selection: [FileItem]

    /// Creates a review. Call `start()` to fill it.
    public init(
        folder: FileItem, scope: NameReviewRules.Scope, selection: [FileItem],
        dependencies: NameReviewDependencies
    ) {
        self.folder = folder
        self.scope = scope
        self.selection = selection
        self.dependencies = dependencies
    }

    /// The rows that show.
    public var rows: [NameProposalSession.Entry] {
        (session?.entries ?? []).filter { plans[$0.id]?.isHidden != true || $0.edit != nil }
    }

    /// The rows behind the line under the list.
    public var hiddenRows: [NameProposalSession.Entry] {
        (session?.entries ?? []).filter { plans[$0.id]?.isHidden == true && $0.edit == nil }
    }

    /// Whether the user always skips an item here.
    public func isAlwaysSkipped(_ id: FileItem.ID) -> Bool {
        plans[id]?.isAlwaysSkipped == true
    }

    /// Reads the folder and the modules, and starts asking for values.
    public func start() async {
        folderItems = (try? await dependencies.operations.contents(of: folder.id)) ?? []
        let visible = folderItems.filter { !$0.isHidden }
        // A provider lists items in no particular order; the rows follow the names.
        items = (scope == .selection ? selection : visible.filter { !$0.isContainer }).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        let (descriptions, catalog) = await loadSettings()
        await dropStaleSavedPatternLinks(descriptions)
        // Subfolders get no names proposed, so they do not count against a pattern.
        let names = visible.filter { !$0.isContainer }.map(\.name)
        modules = []
        // The folder's order of the add-ons (ADR 0065), or else the default order, with
        // one new to the folder last.
        let order = settings.ordered(catalog)
        for description in descriptions.sorted(by: {
            (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0)
        }) {
            modules.append(await makeModule(description, names: names))
        }
        for item in items {
            facts[item.id] = await dependencies.makeRequest(item, visible, [])
        }
        session = NameProposalSession(
            items: items.map {
                .init(id: $0.id, folder: folder.id, originalName: $0.name, kind: $0.kind)
            },
            moduleOrder: enabled)
        replan()
        selectedID = rows.first?.id
    }

    /// Waits until the modules have answered.
    public func waitUntilRead() async {
        await reading?.value
    }

    /// Stops asking, when the overview closes.
    public func stop() {
        reading?.cancel()
    }

    /// Reads the folder's settings and the modules it is offered, after asking the paid
    /// ones about their licence (ADR 0071); a trial starts only when the user asks
    /// (ADR 0088). No module that another replaces is offered, while that one may work, and
    /// the settings go to the one that may (ADR 0067); none turned off in Settings is
    /// offered (ADR 0070). One without a licence comes last, off.
    private func loadSettings() async -> (descriptions: [NameModuleDescription], catalog: [String])
    {
        let all = (try? await dependencies.host.availableModules()) ?? []
        let states = await licenceStates(of: all)
        let mayWork = { (module: NameModuleDescription) in states[module.id]?.mayWork ?? true }
        let offered = NameModuleDescription.offered(all.filter(mayWork))
        var addOns = dependencies.addOns
        let saved = await dependencies.store.settings(forFolderAt: folder.id.rawValue)
        isFirstReview = saved == nil
        settings = saved ?? FolderSettings(enabledModules: [], templates: [:])
        for module in all where !mayWork(module) {
            for replaced in module.replaces {
                addOns.handOver(from: module.id, to: replaced)
                settings.handOver(from: module.id, to: replaced)
            }
        }
        for module in offered {
            for replaced in module.replaces {
                addOns.handOver(from: replaced, to: module.id)
                settings.handOver(from: replaced, to: module.id)
            }
        }
        working = addOns.available(offered.map(\.id))
        freshEnabled =
            addOns.newFolder(
                catalog: offered.map(\.id),
                defaultID: NameModuleDescription.defaultID(among: offered)
            ).enabledModules
        if saved == nil { settings = FolderSettings(enabledModules: freshEnabled, templates: [:]) }
        let locked = all.filter { !mayWork($0) && addOns.isOn($0.id) }
        return (offered.filter { working.contains($0.id) } + locked, working + locked.map(\.id))
    }

    /// Each paid module's licence state; the context they were asked with is kept for the
    /// review.
    private func licenceStates(of modules: [NameModuleDescription]) async
        -> [String: ModuleLicenceState]
    {
        licence = dependencies.licence()
        var states: [String: ModuleLicenceState] = [:]
        for module in modules where !module.isFree {
            states[module.id] = try? await dependencies.host.licenceState(
                moduleID: module.id, licence: licence)
        }
        licenceStates = states
        return states
    }

    private func makeModule(_ description: NameModuleDescription, names: [String]) async
        -> NameReviewModule
    {
        let templates =
            (try? await dependencies.host.derivedTemplates(
                moduleID: description.id, names: names, folderName: folder.name,
                licence: licence)) ?? []
        let derived = templates.first
        // The default module imposes no pattern on a folder that shows none.
        let isDefault = description.takesTheDefaultModulesPart
        var module = NameReviewModule(
            description: description, isOn: enabled.contains(description.id),
            templateText: "", origin: .notRecognized,
            recognized: derived ?? (isDefault ? nil : description.defaultTemplate))
        module.licence = licenceStates[description.id]
        module.candidates = candidates(templates, for: description, names: names)
        if let own = settings.templates[description.id] {
            module.templateText = own
            module.origin = .user
            module.template = Self.parse(own, for: description)
        }
        if module.template == nil { applyRecognized(to: &module) }
        return module
    }

    /// The templates a module recognized, with how many of the folder's names each fits,
    /// as Treewise's own matcher counts them, not the module.
    private func candidates(
        _ templates: [String], for description: NameModuleDescription, names: [String]
    ) -> [PatternCandidate] {
        let stems = names.map(ProposedName.stem(of:))
        return templates.compactMap { text in
            guard let template = Self.parse(text, for: description) else { return nil }
            let fits = stems.count {
                template.matches($0, fixed: [NameTemplate.Field.folder.name: folder.name])
            }
            return PatternCandidate(text: text, fits: fits, of: stems.count)
        }
    }

    /// Gives a module what it recognized, its default, or for selected files in a folder
    /// without a pattern, the user's own default.
    func applyRecognized(to module: inout NameReviewModule) {
        module.templateProblem = nil
        if let recognized = module.recognized {
            module.templateText = recognized
            module.template = Self.parse(recognized, for: module.description)
            module.origin =
                recognized == module.description.defaultTemplate ? .moduleDefault : .derived
        } else if scope == .selection {
            module.templateText = dependencies.defaultPattern
            module.template = Self.parse(dependencies.defaultPattern, for: module.description)
            module.origin = .usersDefault
        } else {
            module.templateText = ""
            module.template = nil
            module.origin = .notRecognized
        }
    }

    static func parse(_ text: String, for description: NameModuleDescription) -> NameTemplate? {
        try? NameTemplate.parse(
            text, fields: description.fields + NameTemplate.Field.suppliedByTreewise
        ).get()
    }
}
