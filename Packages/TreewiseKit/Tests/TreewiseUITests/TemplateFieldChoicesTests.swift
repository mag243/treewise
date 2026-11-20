import Testing
import TreewiseCore
import TreewiseUI

/// The fields Insert Field offers in a template's tree, on the Mac and the iPad alike
/// (ADR 0096, ADR 0100, ADR 0143).
@Suite struct TemplateFieldChoicesTests {
    @Test func offersEveryFieldButTheNumberBelowTheRoot() {
        #expect(
            TemplateFieldChoices.offered(atRoot: false).map(\.field) == [
                "{year}", "{year:yy}", "{text}", "{date:yyyy-MM-dd}", "{month:MM MMMM}",
                "Q{quarter}", "H{half}",
            ])
    }

    @Test func offersNoRepeatAtTheRoot() {
        let atRoot = TemplateFieldChoices.offered(atRoot: true).map(\.field)
        #expect(!atRoot.contains("Q{quarter}"))
        #expect(atRoot.contains("{year}"))
    }

    @Test func addsAFieldAfterANameWithASpace() {
        #expect(
            TemplateFieldChoices.name("Kwartaal", adding: "Q{quarter}") == "Kwartaal Q{quarter}")
        #expect(TemplateFieldChoices.name("", adding: "{year}") == "{year}")
    }
}
