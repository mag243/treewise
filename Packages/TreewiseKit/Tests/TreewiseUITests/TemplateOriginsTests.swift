import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport
import TreewiseUI

/// A folder made from a template remembers it, a year's folder made from the year before
/// takes the year before's, and the details pane forgets one (ADR 0141).
@MainActor
@Suite struct TemplateOriginsTests {
    private static let household = FolderTemplate(
        id: "household", name: "Household Year", root: FolderTree(name: FolderTree.yearField))
    private static let club = FolderTemplate(
        id: "club", name: "Club Year", root: FolderTree(name: FolderTree.yearField))

    let settings = MemoryFolderSettings()

    private func model() -> TemplateBarModel {
        TemplateBarModel(
            fileSystem: ChangingFileSystem(), settings: settings,
            templates: MemoryFolderTemplates([Self.household, Self.club]),
            addOnMayWork: { true })
    }

    @Test func aFolderMadeFromATemplateRemembersIt() async {
        let model = model()
        await model.remember(made: "Admin/2026", from: "household", yearBefore: nil)
        #expect(await model.templates(madeFrom: "Admin/2026").map(\.id) == ["household"])
    }

    @Test func aYearMadeFromTheYearBeforeTakesItsTemplates() async {
        let model = model()
        await model.remember(made: "Admin/2025", from: "club", yearBefore: nil)
        await model.remember(made: "Admin/2026", from: nil, yearBefore: "Admin/2025")
        #expect(await model.templates(madeFrom: "Admin/2026").map(\.id) == ["club"])
    }

    @Test func keepsTheYearBeforesTemplatesAndItsOwn() async {
        let model = model()
        await model.remember(made: "Admin/2025", from: "club", yearBefore: nil)
        await model.remember(made: "Admin/2026", from: "household", yearBefore: "Admin/2025")
        #expect(await model.templates(madeFrom: "Admin/2026").map(\.id) == ["household", "club"])
    }

    @Test func theTemplateUsedLastComesFirst() async {
        let model = model()
        await model.remember(made: "Admin/2026", from: "household", yearBefore: nil)
        await model.remember(made: "Admin/2026", from: "club", yearBefore: nil)
        #expect(await model.templates(madeFrom: "Admin/2026").map(\.id) == ["club", "household"])
    }

    @Test func aTemplateThatIsGoneCountsAsNone() async {
        let model = model()
        await model.remember(made: "Admin/2026", from: "deleted", yearBefore: nil)
        #expect(await model.templates(madeFrom: "Admin/2026").isEmpty)
    }

    @Test func forgetsOneTemplateOfAFolder() async {
        let model = model()
        await model.remember(made: "Admin/2026", from: "household", yearBefore: nil)
        await model.remember(made: "Admin/2026", from: "club", yearBefore: nil)
        await model.forget("club", madeFrom: "Admin/2026")
        #expect(await model.templates(madeFrom: "Admin/2026").map(\.id) == ["household"])
    }
}
