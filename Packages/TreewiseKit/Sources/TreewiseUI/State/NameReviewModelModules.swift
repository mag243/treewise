import Foundation
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface

extension NameReviewModel {
    /// Turns a module on or off, for this folder. The last one stays on.
    public func setModule(_ id: String, on: Bool) async {
        settings.setModule(id, on: on, order: modules.map(\.id))
        for index in modules.indices {
            modules[index].isOn = settings.enabledModules.contains(modules[index].id)
        }
        session?.setModuleOrder(settings.enabledModules)
        replan()
        await saveSettings()
    }

    /// Takes what was typed as a module's template. One that cannot be used shows why,
    /// and the last usable one stays in force. Names follow without asking the module.
    public func setTemplate(_ id: String, to text: String) async {
        guard let index = modules.firstIndex(where: { $0.id == id }) else { return }
        modules[index].templateText = text
        let parsed = NameTemplate.parse(text, fields: modules[index].description.fields + [.folder])
        switch parsed {
        case .failure(let problem):
            modules[index].templateProblem = problem
        case .success(let template):
            modules[index].templateProblem = nil
            modules[index].template = template
            modules[index].origin =
                text == modules[index].recognized ? modules[index].origin : .user
            settings.templates[id] = text
            measureDates()
            replan()
            await saveSettings()
        }
    }

    /// Returns to what the module recognizes in this folder, or to its default.
    public func resetTemplate(_ id: String) async {
        guard let index = modules.firstIndex(where: { $0.id == id }) else { return }
        let module = modules[index]
        settings.templates[id] = nil
        modules[index].templateText = module.recognized
        modules[index].templateProblem = nil
        modules[index].template = Self.parse(module.recognized, for: module.description)
        modules[index].origin =
            module.recognized == module.description.defaultTemplate ? .moduleDefault : .derived
        measureDates()
        replan()
        await saveSettings()
    }

    /// Whether a whole-folder review always leaves this file out.
    public func alwaysSkip(_ id: FileItem.ID) async {
        guard let item = items.first(where: { $0.id == id }) else { return }
        settings.alwaysSkipped.insert(item.name)
        replan()
        await saveSettings()
    }

    /// Takes a file back into the list.
    public func stopAlwaysSkipping(_ id: FileItem.ID) async {
        guard let item = items.first(where: { $0.id == id }) else { return }
        settings.alwaysSkipped.remove(item.name)
        replan()
        await saveSettings()
    }

    /// Whether the user trusts dates inside this folder's files.
    public func setTrustsDatesInFiles(_ trusts: Bool) async {
        settings.trustsDatesInFiles = trusts
        measureDates()
        await saveSettings()
    }

    /// Whether the user trusts dates inside this folder's files.
    public var trustsDatesInFiles: Bool { settings.trustsDatesInFiles }

    /// Judges dates inside files against the dates in the names already there.
    func measureDates() {
        let templates = modules.filter(\.isOn).compactMap(\.template)
        let samples = items.compactMap { item -> DateReliability.Sample? in
            guard let inside = facts[item.id]?.suggestedDate, inside.source == .insideFile else {
                return nil
            }
            let stem = ProposedName.stem(of: ProposedName.shownName(fromDisk: item.name))
            guard let inName = templates.lazy.compactMap({ $0.date(in: stem) }).first else {
                return nil
            }
            return .init(inName: inName, insideFile: inside.value)
        }
        dateInFileIsReliable = settings.trustsDatesInFiles || DateReliability.isReliable(samples)
    }

    /// Decides again what happens to every item, from what is known now, and asks for
    /// what is still missing.
    func replan() {
        let on = modules.filter(\.isOn)
        let reviewModules = on.compactMap { module in
            module.template.map { NameReviewRules.Module(id: module.id, template: $0) }
        }
        var pending: [(item: FileItem, module: NameReviewModule)] = []
        for item in items {
            guard let contentType = facts[item.id]?.contentType else { continue }
            let handledBy = on.filter {
                ModuleScope.handles(
                    contentTypes: $0.description.contentTypes, contentType: contentType)
            }.map(\.id)
            let plan = NameReviewRules.plan(
                for: .init(name: item.name, kind: item.kind, handledBy: handledBy),
                in: .init(name: folder.name, alwaysSkipped: settings.alwaysSkipped), scope: scope,
                modules: reviewModules)
            plans[item.id] = plan
            session?.setFit(item.id, moduleIDs: plan?.fittingModules ?? [])
            session?.setOutOfScope(item.id, plan?.isOutOfScope == true)
            session?.replaceProposals(
                plan?.repair.map { [$0] } ?? [], from: NameProposal.treewiseID, for: item.id)
            for module in modules { refreshProposals(of: item, from: module.id) }
            for id in plan?.modulesToAsk ?? [] where answers[item.id]?[id] == nil {
                if let module = on.first(where: { $0.id == id }) { pending.append((item, module)) }
            }
        }
        refreshConflicts()
        ask(pending)
    }

    /// Makes an item's proposals from a module's answer and its template.
    func refreshProposals(of item: FileItem, from moduleID: String) {
        guard let module = modules.first(where: { $0.id == moduleID }), module.isOn,
            let template = module.template, plans[item.id]?.modulesToAsk.contains(moduleID) == true,
            let values = answers[item.id]?[moduleID]
        else {
            session?.replaceProposals([], from: moduleID, for: item.id)
            return
        }
        let proposals = NameProposal.make(
            from: values, template: template, moduleID: moduleID, folderName: folder.name,
            suggestedDate: facts[item.id]?.suggestedDate)
        session?.replaceProposals(proposals, from: moduleID, for: item.id)
    }

    /// Finds what stands in the way of every name shown now, before anything is applied.
    func refreshConflicts() {
        let renames = (session?.entries ?? []).compactMap { entry -> BatchRename? in
            guard entry.state != .skipped, let name = entry.currentName, entry.problem == nil
            else { return nil }
            return BatchRename(
                item: entry.id, folder: entry.folder, from: entry.originalName,
                to: ProposedName.diskName(fromShown: name))
        }
        let plan = BatchRenamePlanner.plan(
            renames, namesInFolders: [folder.id: folderItems.map(\.name)])
        guard case .conflicts(let found) = plan else {
            conflicts = [:]
            return
        }
        conflicts = Dictionary(found.map { ($0.item, $0.kind) }) { first, _ in first }
    }

    func saveSettings() async {
        await dependencies.store.save(settings, forFolderAt: folder.id.rawValue)
    }
}
