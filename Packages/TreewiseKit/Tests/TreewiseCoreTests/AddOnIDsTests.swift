import Foundation
import Testing
import TreewiseCore

/// The ids add-ons had before keep working: what is read with one holds the current id
/// (ADR 0140).
@Suite struct AddOnIDsTests {
    private static let oldFree = "me.m-domain.treewise.folder-pattern"
    private static let newFree = "me.m-domain.treewise.file-name-patterns"
    private static let oldPaid = "me.m-domain.treewise.folder-pattern-advanced"
    private static let newPaid = "me.m-domain.treewise.file-name-patterns-advanced"

    private func decode<Value: Decodable>(_ type: Value.Type, _ json: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test func aFormerIDGivesTheCurrentOne() {
        #expect(AddOnIDs.current(Self.oldFree) == Self.newFree)
        #expect(AddOnIDs.current(Self.oldPaid) == Self.newPaid)
    }

    @Test func anyOtherIDStaysAsItIs() {
        #expect(AddOnIDs.current(Self.newFree) == Self.newFree)
        #expect(AddOnIDs.current("com.example.invoices") == "com.example.invoices")
    }

    @Test func anAddOnKnowsItsFormerIDs() {
        #expect(AddOnIDs.formerIDs(of: Self.newPaid) == [Self.oldPaid])
        #expect(AddOnIDs.formerIDs(of: "com.example.invoices").isEmpty)
    }

    @Test func aTextWithAFormerIDIsFound() {
        #expect(AddOnIDs.holdsFormerID(#"{"enabledModules":["\#(Self.oldPaid)"]}"#))
        #expect(!AddOnIDs.holdsFormerID(#"{"enabledModules":["\#(Self.newFree)"]}"#))
    }

    @Test func folderSettingsReadWithFormerIDsHoldTheCurrentOnes() throws {
        let settings = try decode(
            FolderSettings.self,
            #"""
            {"enabledModules": ["\#(Self.oldPaid)", "\#(Self.oldFree)"],
             "templates": {"\#(Self.oldPaid)": "{year} Tax {seq}"},
             "moduleOrder": ["\#(Self.oldFree)", "\#(Self.oldPaid)"]}
            """#)
        #expect(settings.enabledModules == [Self.newPaid, Self.newFree])
        #expect(settings.templates == [Self.newPaid: "{year} Tax {seq}"])
        #expect(settings.moduleOrder == [Self.newFree, Self.newPaid])
    }

    @Test func aPatternUnderTheCurrentIDWinsOverOneUnderTheFormer() throws {
        let settings = try decode(
            FolderSettings.self,
            #"""
            {"enabledModules": ["\#(Self.oldFree)", "\#(Self.newFree)"],
             "templates": {"\#(Self.oldFree)": "old {text}", "\#(Self.newFree)": "new {text}"}}
            """#)
        #expect(settings.enabledModules == [Self.newFree])
        #expect(settings.templates == [Self.newFree: "new {text}"])
    }

    @Test func aTemplatesNameSettingsReadWithFormerIDsHoldTheCurrentOnes() throws {
        let names = try decode(
            FolderNameSettings.self,
            #"""
            {"enabledModules": ["\#(Self.oldFree)"], "moduleOrder": ["\#(Self.oldPaid)"],
             "patterns": {"\#(Self.oldFree)": "{year} Tax {seq}"}}
            """#)
        #expect(names.enabledModules == [Self.newFree])
        #expect(names.moduleOrder == [Self.newPaid])
        #expect(names.patterns == [Self.newFree: "{year} Tax {seq}"])
    }

    @Test func addOnPreferencesReadWithFormerIDsHoldTheCurrentOnes() throws {
        let preferences = try decode(
            AddOnPreferences.self,
            #"""
            {"turnedOff": ["\#(Self.oldFree)"], "onInNewFolders": ["\#(Self.oldPaid)"],
             "order": ["\#(Self.oldPaid)", "\#(Self.oldFree)"]}
            """#)
        let catalog = [Self.newFree, Self.newPaid]
        #expect(!preferences.isOn(Self.newFree))
        #expect(preferences.isOnInNewFolders(Self.newPaid, defaultID: Self.newFree))
        #expect(preferences.ordered(catalog) == [Self.newPaid, Self.newFree])
    }
}
