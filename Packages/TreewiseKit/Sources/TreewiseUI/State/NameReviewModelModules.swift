import Foundation
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface

extension NameReviewModel {
    /// Turns a module on or off, for this folder. The last one that may work stays on, and
    /// one that may not work, as without a licence, cannot be turned on (ADR 0071).
    public func setModule(_ id: String, on: Bool) async {
        guard working.contains(id), on || enabled != [id] else { return }
        settings.setModule(id, on: on, order: modules.map(\.id))
        for index in modules.indices {
            modules[index].isOn = enabled.contains(modules[index].id)
        }
        session?.setModuleOrder(enabled)
        replan()
        await saveSettings()
    }

    /// Moves a module to a place in the folder's order (ADR 0065). A row that waits for an
    /// approval shows the first option of the new order.
    public func moveModule(_ id: String, to index: Int) async {
        let catalog = modules.map(\.id)
        settings.moveModule(id, to: index, catalog: catalog)
        let order = settings.ordered(catalog)
        modules.sort { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
        session?.reorderModules(enabled)
        refreshConflicts()
        await saveSettings()
    }

    /// Takes what was typed as a module's template. One that cannot be used shows why,
    /// and the last usable one stays in force. Names follow without asking the module.
    /// Spaces at its ends are dropped.
    public func setTemplate(_ id: String, to written: String) async {
        guard let index = modules.firstIndex(where: { $0.id == id }) else { return }
        // A space at either end belongs to no name, so the pattern does not keep it.
        let text = written.trimmingCharacters(in: .whitespaces)
        modules[index].templateText = text
        let parsed = NameTemplate.parse(
            text, fields: modules[index].description.fields + NameTemplate.Field.suppliedByTreewise)
        switch parsed {
        case .failure(let problem):
            modules[index].templateProblem = problem
        case .success(let template):
            modules[index].templateProblem = nil
            modules[index].template = template
            modules[index].origin =
                text == modules[index].recognized ? modules[index].origin : .user
            settings.templates[id] = text
            replan()
            await saveSettings()
        }
    }

    /// Returns to what the module recognizes in this folder, or to its default.
    public func resetTemplate(_ id: String) async {
        guard let index = modules.firstIndex(where: { $0.id == id }) else { return }
        settings.templates[id] = nil
        applyRecognized(to: &modules[index])
        replan()
        await saveSettings()
    }

    /// Uses the user's own default pattern in this folder, which then keeps it.
    public func useDefaultPattern(_ id: String) async {
        await setTemplate(id, to: dependencies.defaultPattern)
    }

    /// The user's own default pattern.
    public var defaultPattern: String { dependencies.defaultPattern }

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
            // A module without a pattern here still handles the file, so it is not out of scope.
            session?.setOutOfScope(item.id, handledBy.isEmpty)
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
        let siblings = folderItems.filter { !$0.isHidden && $0.id != item.id }.map(\.name)
        let proposals = NameProposal.make(
            from: values, template: template, moduleID: moduleID, folderName: folder.name,
            suggestedDate: facts[item.id]?.suggestedDate, siblingNames: siblings,
            currentName: item.name)
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
