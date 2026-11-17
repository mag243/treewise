import Testing
import TreewiseCore

/// When a location asks for a name, and what a typed name leaves (ADR 0119).
@Suite struct LocationLabelTests {
    @Test(arguments: [
        "1B4E28BA-2FA1-11D2-883F-0016D3CCA427",
        "1b4e28ba-2fa1-11d2-883f-0016d3cca427",
    ])
    func aUUIDIsMachineMade(name: String) {
        #expect(LocationLabel.isMachineMade(name))
    }

    @Test(arguments: ["Dropbox", "Documents", "1B4E28BA", "Project 2FA1-11D2", ""])
    func anOrdinaryNameIsNotMachineMade(name: String) {
        #expect(!LocationLabel.isMachineMade(name))
    }

    @Test func aLabelOfOnlySpacesCountsAsNone() {
        #expect(LocationLabel.cleaned("   ") == nil)
        #expect(LocationLabel.cleaned("  Dropbox ") == "Dropbox")
    }
}
