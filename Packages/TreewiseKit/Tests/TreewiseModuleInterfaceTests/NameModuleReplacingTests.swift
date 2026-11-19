import Testing
import TreewiseCore
import TreewiseModuleInterface

/// A module that replaces another, as the advanced file name patterns module replaces the
/// free one (ADR 0067).
@Suite struct NameModuleReplacingTests {
    private static func module(_ id: String, replaces: Set<String> = []) -> AddOnDescription {
        AddOnDescription(
            id: id, contentTypes: ["public.item"], neededContent: [], fields: [],
            defaultTemplate: "{folder}", replaces: replaces)
    }

    private static let free = module(AddOnDescription.defaultModuleID)
    private static let advanced = module(
        "advanced", replaces: [AddOnDescription.defaultModuleID])
    private static let invoices = module("invoices")

    @Test func offersNoModuleThatAnotherReplaces() {
        let offered = AddOnDescription.offered([Self.free, Self.invoices, Self.advanced])
        #expect(offered.map(\.id) == ["invoices", "advanced"])
    }

    @Test func offersEveryModuleWhenNoneReplacesAnother() {
        #expect(AddOnDescription.offered([Self.free, Self.invoices]).map(\.id).count == 2)
    }

    @Test func aModuleThatReplacesTheFreeOneTakesItsPart() {
        #expect(Self.free.takesTheDefaultModulesPart)
        #expect(Self.advanced.takesTheDefaultModulesPart)
        #expect(!Self.invoices.takesTheDefaultModulesPart)
    }

    @Test func theDefaultAmongTheOfferedIsTheOneThatReplacesTheFreeOne() {
        let offered = AddOnDescription.offered([Self.free, Self.advanced])
        #expect(AddOnDescription.defaultID(among: offered) == "advanced")
        #expect(
            AddOnDescription.defaultID(among: [Self.free])
                == AddOnDescription.defaultModuleID)
    }

    @Test func carriesItsNameAndWhatItReplaces() {
        let named = AddOnDescription(
            id: "advanced", contentTypes: [], neededContent: [], fields: [], defaultTemplate: "",
            name: "Folder Pattern Plus", replaces: ["x"])
        #expect(named.name == "Folder Pattern Plus")
        #expect(named.names.replaces == ["x"])
    }
}
