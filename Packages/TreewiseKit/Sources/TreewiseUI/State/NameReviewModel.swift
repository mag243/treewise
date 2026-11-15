import Foundation
import Observation
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface
import os

/// The state of the review overview: proposals for a folder or a selection, the user's
/// choices, and applying them (ADR 0057).
@MainActor
@Observable
public final class NameReviewModel {
    static let logger = Logger(subsystem: LogSubsystem.name, category: "NameReview")

    /// The folder under review.
    public let folder: FileItem
    /// The names of the folders above it, nearest first, for `{folder:2}` and higher
    /// (ADR 0089).
    var foldersAbove: [String] { Array(NameTemplate.folderNames(of: folder.id).dropFirst()) }
    /// The folders' names by the keys a template reads them under.
    var folderValues: [String: String] {
        NameTemplate.folderValues([folder.name] + foldersAbove)
    }
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
    /// The names of the same folder a year before, read for the add-ons that ask (ADR 0090).
    var yearBefore: YearBefore?
    /// Whether an add-on here was given the names of the same folder a year before.
    public var readsYearBefore: Bool {
        yearBefore?.folderFound == true
            && modules.contains { $0.description.names.readsYearBefore && mayWork($0.id) }
    }
    /// Whether a module failed to answer.
    public internal(set) var moduleFailed = false
    /// Why the review shows nothing to name, when it is not that the folder holds nothing.
    public internal(set) var startProblem: StartProblem?

    /// What kept the review from reading what it needs.
    public enum StartProblem: Hashable, Sendable {
        /// The folder could not be read.
        case folderUnreadable
        /// The add-ons' process could not be reached.
        case addOnsUnavailable
    }
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
    /// The paid add-ons whose licence could not be checked; they do not work.
    var uncheckedLicences: Set<String> = []
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
    var folderItems: [FileItem] = [] {
        didSet { folderNames = FolderNames(folderItems.filter { !$0.isHidden }.map(\.name)) }
    }
    /// The names of the folder's visible items, split once for all the proposals there.
    private(set) var folderNames = FolderNames([])
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
        startProblem = nil
        do {
            folderItems = try await dependencies.operations.contents(of: folder.id)
        } catch {
            Self.logger.error("The folder could not be read: \(String(describing: error))")
            folderItems = []
            startProblem = .folderUnreadable
        }
        let visible = folderItems.filter { !$0.isHidden }
        // A provider lists items in no particular order; the rows follow the names.
        items = (scope == .selection ? selection : visible.filter { !$0.isContainer }).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        let (descriptions, catalog) = await loadSettings()
        await dropStaleSavedPatternLinks(descriptions)
        yearBefore = await readYearBefore(for: descriptions)
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
    private func loadSettings() async -> (descriptions: [AddOnDescription], catalog: [String]) {
        let available: [AddOnDescription]
        do {
            available = try await dependencies.host.availableModules()
        } catch {
            Self.logger.error("The add-ons could not be reached: \(String(describing: error))")
            available = []
            startProblem = startProblem ?? .addOnsUnavailable
        }
        let all = available.filter { $0.proposesNames }
        await readLicenceStates(of: all)
        let mayWork = { (module: AddOnDescription) in self.mayWork(module.id) }
        let offered = AddOnDescription.offered(all.filter(mayWork))
        var addOns = dependencies.addOns
        let saved = await dependencies.store.settings(forFolderAt: folder.id.rawValue)
        // A folder kept only for what it says of templates has not been reviewed.
        isFirstReview = saved?.isReviewed != true
        settings = saved ?? FolderSettings(enabledModules: [], templates: [:])
        for module in all where !mayWork(module) {
            for replaced in module.names.replaces {
                addOns.handOver(from: module.id, to: replaced)
                settings.handOver(from: module.id, to: replaced)
            }
        }
        for module in offered {
            for replaced in module.names.replaces {
                addOns.handOver(from: replaced, to: module.id)
                settings.handOver(from: replaced, to: module.id)
            }
        }
        working = addOns.available(offered.map(\.id))
        freshEnabled =
            addOns.newFolder(
                catalog: offered.map(\.id),
                defaultID: AddOnDescription.defaultID(among: offered)
            ).enabledModules
        if isFirstReview { settings = FolderSettings(enabledModules: freshEnabled, templates: [:]) }
        let locked = all.filter { !mayWork($0) && addOns.isOn($0.id) }
        return (offered.filter { working.contains($0.id) } + locked, working + locked.map(\.id))
    }

    /// Reads each paid module's licence state, and which could not be checked; the context
    /// they were asked with is kept for the review.
    private func readLicenceStates(of modules: [AddOnDescription]) async {
        licence = dependencies.licence()
        var states: [String: ModuleLicenceState] = [:]
        var failed: Set<String> = []
        for module in modules where !module.isFree {
            do {
                states[module.id] = try await dependencies.host.licenceState(
                    moduleID: module.id, licence: licence)
            } catch {
                // Unknown is not free: a paid add-on whose licence cannot be read does not work.
                Self.logger.error("A licence could not be checked: \(String(describing: error))")
                failed.insert(module.id)
            }
        }
        licenceStates = states
        uncheckedLicences = failed
    }

    private func makeModule(_ description: AddOnDescription, names: [String]) async
        -> NameReviewModule
    {
        let years = years(for: description)
        let templates =
            (try? await dependencies.host.derivedTemplates(
                moduleID: description.id, names: names, folderName: folder.name, years: years,
                licence: licence)) ?? []
        let derived = templates.first
        // The default module imposes no pattern on a folder that shows none.
        let isDefault = description.takesTheDefaultModulesPart
        var module = NameReviewModule(
            description: description, isOn: enabled.contains(description.id),
            templateText: "", origin: .notRecognized,
            recognized: derived ?? (isDefault ? nil : description.names.defaultTemplate))
        module.licence = licenceStates[description.id]
        module.namesGiven = names.count + (years?.namesYearBefore.count ?? 0)
        module.candidates = candidates(templates, for: description, names: names)
        if years != nil, names.count < PatternFit.minimumFits, let before = yearBefore,
            !before.years.namesYearBefore.isEmpty
        {
            module.candidates = candidates(
                templates, for: description, names: before.years.namesYearBefore,
                fixed: before.folderValues)
            module.recognizedInYearBefore = derived != nil
        }
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
        _ templates: [String], for description: AddOnDescription, names: [String],
        fixed: [String: String]? = nil
    ) -> [PatternCandidate] {
        let stems = names.map(ProposedName.stem(of:))
        let fixed = fixed ?? folderValues
        return templates.compactMap { text in
            guard let template = Self.parse(text, for: description) else { return nil }
            let fits = stems.count(where: template.matcher(fixed: fixed))
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
                recognized == module.description.names.defaultTemplate ? .moduleDefault : .derived
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

    static func parse(_ text: String, for description: AddOnDescription) -> NameTemplate? {
        try? NameTemplate.parse(
            text, fields: description.names.fields + NameTemplate.Field.suppliedByTreewise
        ).get()
    }
}
