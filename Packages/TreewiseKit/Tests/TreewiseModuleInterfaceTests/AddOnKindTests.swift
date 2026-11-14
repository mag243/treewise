import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface

/// Add-ons of two kinds, one description for both (ADR 0091, ADR 0098): those that propose
/// names, with what that needs, and those that make folder structures.
@Suite struct AddOnKindTests {
    private static let names = AddOnDescription(
        id: "names", contentTypes: ["public.data"], neededContent: [],
        fields: [NameTemplate.Field(name: "text", kind: .text)], defaultTemplate: "{text}")
    private static let folders = AddOnDescription(id: "folders", kind: .folderStructure)

    @Test func anAddOnDescribedWithWhatNamesNeedProposesNames() {
        #expect(Self.names.proposesNames)
        #expect(!Self.names.makesFolderStructures)
        #expect(Self.names.names.defaultTemplate == "{text}")
    }

    @Test func anAddOnThatMakesFolderStructuresHasNothingForNames() {
        #expect(Self.folders.makesFolderStructures)
        #expect(!Self.folders.proposesNames)
        #expect(Self.folders.names == .none)
    }

    @Test func keepsItsKindOnTheTrip() throws {
        for description in [Self.names, Self.folders] {
            let decoded = try PropertyListDecoder().decode(
                AddOnDescription.self, from: PropertyListEncoder().encode(description))
            #expect(decoded == description)
        }
    }

    @Test func onlyAnAddOnForNamesIsOfferedForNames() {
        let offered = AddOnDescription.offered(forNames: [Self.names, Self.folders])
        #expect(offered.map(\.id) == ["names"])
    }

    @Test func anAddOnForFoldersNeverTakesTheDefaultModulesPart() {
        let folders = AddOnDescription(
            id: AddOnDescription.defaultModuleID, kind: .folderStructure)
        #expect(!folders.takesTheDefaultModulesPart)
    }
}
