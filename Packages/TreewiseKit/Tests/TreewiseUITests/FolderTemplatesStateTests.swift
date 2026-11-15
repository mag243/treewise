import Testing
import TreewiseUI

/// Whether the add-on that makes folder structures may work (ADR 0091, ADR 0088).
@MainActor
@Suite struct FolderTemplatesStateTests {
    @Test func mayWorkOnlyWithAnAddOnThatMayWork() {
        let state = FolderTemplatesState()
        #expect(!state.addOnMayWork)
        state.found(addOnID: "templates", mayWork: false, addOnNames: [:])
        #expect(!state.addOnMayWork)
        state.found(addOnID: nil, mayWork: true, addOnNames: [:])
        #expect(!state.addOnMayWork)
        state.found(addOnID: "templates", mayWork: true, addOnNames: ["templates": "Templates"])
        #expect(state.addOnMayWork)
        #expect(state.addOnNames == ["templates": "Templates"])
    }
}
