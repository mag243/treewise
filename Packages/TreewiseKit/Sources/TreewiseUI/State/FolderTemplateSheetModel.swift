import Foundation
import Observation
import TreewiseCore

/// The sheet of New Folders from Template (ADR 0091, ADR 0095 to ADR 0097): the template's
/// fields with what they propose, the tree they make, planned against the folder, and whether
/// Create Folders can make it. Treewise fills in the fields itself, so the sheet works without
/// an add-on (ADR 0099).
@MainActor
@Observable
public final class FolderTemplateSheetModel {
    /// Where the tree goes.
    public enum Place: Hashable, Sendable {
        /// The root is made inside this folder.
        case inside(FileItem.ID)
        /// This folder, already there, is filled under its own name: only the folders below
        /// the root are made, as for a year's folder or the bar (ADR 0095, ADR 0097).
        case filling(FileItem)
    }

    /// Why Create Folders cannot make the tree.
    public enum Problem: Hashable, Sendable {
        /// The text a name needs is not typed yet.
        case textNeeded
        /// A name the fields make cannot be a folder's.
        case tree(FolderTree.Problem)
        /// A field of the template has no value to write in.
        case fieldWithoutValue
    }

    /// The template's tree, with its fields.
    public let template: FolderTree
    /// Where it goes.
    public let place: Place
    /// The fields the sheet asks, in the order they first appear.
    public let fields: [FolderTemplateField]
    /// The values of the fields, as proposed and typed.
    public private(set) var values: FolderTemplateValues
    /// The folders of the tree, with what becomes of each, as planned now.
    public private(set) var entries: [FolderTemplatePlan.Entry] = []
    /// Why the tree cannot be made, or nil when it can.
    public private(set) var problem: Problem?
    /// The tree to make, once it can be.
    public private(set) var tree: FolderTree?

    private let fileSystem: any FileSystemProviding
    private let currentYear: Int
    /// The names of the folders in the folder the root goes into, for the number.
    private var besideRoot: [String] = []
    private var generation = 0

    /// A sheet for `template` placed at `place`, whose folders it reads from `fileSystem`.
    /// `start()` proposes the year and the number from them; the date is `today` and, for a
    /// folder filled, the text its name and the year that of its path.
    public init(
        template: FolderTree, place: Place, fileSystem: any FileSystemProviding,
        currentYear: Int, today: FolderTemplateValues.Day,
        language: MonthNames.Language = .app
    ) {
        self.template = template
        self.place = place
        self.fileSystem = fileSystem
        self.currentYear = currentYear
        var values = FolderTemplateValues(year: currentYear, date: today, language: language)
        switch place {
        case .inside:
            fields = template.fields
        case .filling(let folder):
            // A folder with a year in its path gives that year, which is then not asked.
            let pathYear = YearFolders.year(of: folder.id)
            fields = template.fieldsBelowRoot.filter { $0 != .year || pathYear == nil }
            values.year = pathYear ?? currentYear
            values.text = folder.name
        }
        self.values = values
    }

    /// Reads the folder, proposes the year and the number, and shows the tree for them.
    public func start() async {
        if case .inside(let folder) = place {
            let shallow = (try? await fileSystem.contents(of: folder)) ?? []
            besideRoot = shallow.filter { $0.kind == .folder }.map(\.name)
            if fields.contains(.year) {
                let years = besideRoot.compactMap(YearFolders.year(named:))
                let highest = years.max() ?? currentYear
                let deep = await read(template.filling(year: highest), in: folder)
                values.year = template.proposedYear(in: deep, currentYear: currentYear)
            }
            values.number = proposedNumber()
        }
        await refresh()
    }

    /// What `folder` holds along `tree`, as deep as the tree goes.
    private func read(_ tree: FolderTree, in folder: FileItem.ID) async -> FolderContents {
        let wrapper = FolderTree(name: "", folders: [tree])
        return (try? await fileSystem.folderContents(for: wrapper, in: folder)) ?? FolderContents()
    }

    /// The number the root proposes beside the folders there, for the year chosen. The text
    /// typed is left out, so the number counts among every folder of that year.
    private func proposedNumber() -> FolderTemplateValues.Number? {
        guard case .inside = place else { return nil }
        var counting = values
        counting.text = nil
        return template.proposedNumber(beside: besideRoot, values: counting)
    }

    /// Sets the year; the number follows it, as it counts within the year (ADR 0096).
    public func setYear(_ year: Int) async {
        values.year = year
        values.number = proposedNumber()
        await refresh()
    }

    /// Sets the text.
    public func setText(_ text: String) async {
        values.text = text
        await refresh()
    }

    /// Sets the number, in the width proposed.
    public func setNumber(_ number: Int) async {
        values.number = FolderTemplateValues.Number(
            value: number, width: values.number?.width ?? 1)
        await refresh()
    }

    /// Sets the date.
    public func setDate(_ date: FolderTemplateValues.Day) async {
        values.date = date
        await refresh()
    }

    /// The number of folders Create Folders makes now.
    public var toMakeCount: Int { entries.filter { $0.state == .new }.count }

    /// Whether Create Folders can make the tree now.
    public var canCreate: Bool { problem == nil && toMakeCount > 0 }

    /// Fills in the template with the values, checks the tree and plans it against the
    /// folder. A plan for values typed over since is dropped.
    public func refresh() async {
        generation += 1
        let asked = generation
        if fields.contains(.text),
            values.text?.trimmingCharacters(in: .whitespaces).isEmpty != false
        {
            return await show(nil, .textNeeded, asked)
        }
        // A folder filled keeps its name, so the root's own fields are not asked.
        let question: FolderTree
        if case .filling(let folder) = place {
            question = template.filling(folderNamed: folder.name)
        } else {
            question = template
        }
        let made = question.filling(values)
        guard made.fields.isEmpty else { return await show(nil, .fieldWithoutValue, asked) }
        do {
            try made.check()
            await show(made, nil, asked)
        } catch {
            await show(nil, .tree(error), asked)
        }
    }

    private func show(_ made: FolderTree?, _ found: Problem?, _ asked: Int) async {
        guard asked == generation else { return }
        guard let made, let folder = folderMadeIn else {
            problem = found
            tree = nil
            entries = []
            return
        }
        let there = await read(made, in: folder)
        guard asked == generation else { return }
        problem = found
        tree = made
        entries = FolderTemplatePlan(making: made, in: there).entries
    }

    /// The folder Create Folders makes the tree in: the one chosen, or the one above the
    /// folder filled.
    public var folderMadeIn: FileItem.ID? {
        switch place {
        case .inside(let folder): folder
        case .filling(let folder): folder.parentID
        }
    }
}
