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

    let operations: any FileOperating
    let host: any NameModuleHosting
    let store: any FolderSettingsStoring
    /// The user's pattern for a folder without one.
    let defaultPattern: String
    /// What Approve All does with a name that holds personal data.
    let personalDataInNames: PersonalDataInNames
    let makeRequest: MakeRequest

    /// Creates the dependencies.
    public init(
        operations: any FileOperating, host: any NameModuleHosting,
        store: any FolderSettingsStoring, defaultPattern: String,
        personalDataInNames: PersonalDataInNames = .leaveOutOfApproveAll,
        makeRequest: @escaping MakeRequest
    ) {
        self.operations = operations
        self.host = host
        self.store = store
        self.defaultPattern = defaultPattern
        self.personalDataInNames = personalDataInNames
        self.makeRequest = makeRequest
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

    /// The module's id.
    public var id: String { description.id }
}

/// The state of the review overview: proposals for a folder or a selection, the user's
/// choices, and applying them (ADR 0057).
@MainActor
@Observable
public final class NameReviewModel {
    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "NameReview")

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
    /// Whether the overview's window is closing.
    public var isClosing = false
    /// What applying did, once it ran.
    public internal(set) var outcome: BatchRenameOutcome?
    /// What each item's plan says.
    var plans: [FileItem.ID: NameReviewRules.Plan] = [:]
    /// The folder's settings.
    var settings = FolderSettings(enabledModules: [], templates: [:])
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
        let descriptions = (try? await dependencies.host.availableModules()) ?? []
        let saved = await dependencies.store.settings(forFolderAt: folder.id.rawValue)
        isFirstReview = saved == nil
        settings = saved ?? .new(defaultModuleID: NameModuleDescription.defaultModuleID)
        let names = visible.map(\.name)
        modules = []
        for description in descriptions {
            modules.append(await makeModule(description, names: names))
        }
        for item in items {
            facts[item.id] = await dependencies.makeRequest(item, visible, [])
        }
        session = NameProposalSession(
            items: items.map {
                .init(id: $0.id, folder: folder.id, originalName: $0.name, kind: $0.kind)
            },
            moduleOrder: settings.enabledModules)
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

    private func makeModule(_ description: NameModuleDescription, names: [String]) async
        -> NameReviewModule
    {
        let derived = try? await dependencies.host.derivedTemplate(
            moduleID: description.id, names: names)
        // The default module imposes no pattern on a folder that shows none.
        let isDefault = description.id == NameModuleDescription.defaultModuleID
        var module = NameReviewModule(
            description: description, isOn: settings.enabledModules.contains(description.id),
            templateText: "", origin: .notRecognized,
            recognized: derived ?? (isDefault ? nil : description.defaultTemplate))
        if let own = settings.templates[description.id] {
            module.templateText = own
            module.origin = .user
            module.template = Self.parse(own, for: description)
        }
        if module.template == nil { applyRecognized(to: &module) }
        return module
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
        try? NameTemplate.parse(text, fields: description.fields + [.folder]).get()
    }

    /// Runs while a module's answer arrives; one that fails leaves the rest.
    func ask(_ pending: [(item: FileItem, module: NameReviewModule)]) {
        guard !pending.isEmpty else { return }
        let previous = reading
        readingCount += pending.count
        reading = Task {
            await previous?.value
            for (item, module) in pending where !Task.isCancelled {
                await read(item, module)
                readingCount -= 1
            }
        }
    }

    private func read(_ item: FileItem, _ module: NameReviewModule) async {
        let visible = folderItems.filter { !$0.isHidden }
        let request = await dependencies.makeRequest(
            item, visible, module.description.neededContent)
        do {
            let values = try await dependencies.host.fieldValues(
                moduleID: module.id, request: request)
            answers[item.id, default: [:]][module.id] = values
            refreshProposals(of: item, from: module.id)
            refreshConflicts()
        } catch {
            Self.logger.error("A module gave no answer: \(String(describing: error))")
            moduleFailed = true
        }
    }
}
