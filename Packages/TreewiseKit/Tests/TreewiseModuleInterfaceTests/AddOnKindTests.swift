import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface

/// Add-ons of two kinds: those that propose names and those that make folder structures
/// (ADR 0091).
@Suite struct AddOnKindTests {
    private func describe(_ id: String, kind: AddOnKind) -> NameModuleDescription {
        NameModuleDescription(
            id: id, contentTypes: [], neededContent: [], fields: [], defaultTemplate: "",
            kind: kind)
    }

    @Test func anAddOnProposesNamesUnlessItSaysOtherwise() {
        let description = NameModuleDescription(
            id: "m", contentTypes: ["public.data"], neededContent: [], fields: [],
            defaultTemplate: "{folder}")
        #expect(description.kind == .names)
    }

    @Test func keepsItsKindOnTheTrip() throws {
        let description = describe("t", kind: .folderStructure)
        let decoded = try PropertyListDecoder().decode(
            NameModuleDescription.self, from: PropertyListEncoder().encode(description))
        #expect(decoded.kind == .folderStructure)
    }

    @Test func onlyAnAddOnForNamesIsOfferedForNames() {
        let all = [describe("names", kind: .names), describe("folders", kind: .folderStructure)]
        #expect(NameModuleDescription.offered(forNames: all).map(\.id) == ["names"])
    }

    @Test func anAddOnForFoldersNeverTakesTheDefaultModulesPart() {
        let folders = NameModuleDescription(
            id: "folders", contentTypes: [], neededContent: [], fields: [], defaultTemplate: "",
            replaces: [NameModuleDescription.defaultModuleID], kind: .folderStructure)
        #expect(!folders.takesTheDefaultModulesPart)
    }
}
