import Testing
import TreewiseCore

/// Matching many names at once says what matching each name says.
@Suite struct NameTemplateMatcherTests {
    private static let fields = [
        NameTemplate.Field(name: "date", kind: .date),
        NameTemplate.Field(name: "text", kind: .text),
        NameTemplate.Field(name: "number", kind: .number),
    ]
    private static let names = [
        "2026-03-01 Invoice", "2026-03-01  Invoice", "Invoices 2026-03-01 Invoice",
        "F26009 Invoice", "Holiday", "2026-03-01 Invoices", "",
    ]

    @Test(arguments: [
        "{date} {text}", "{number|date} Invoice", "{folder} {date} {text}", "[{date} ]{text}",
    ])
    func agreesWithMatchingOneName(_ text: String) throws {
        let template = try NameTemplate.parse(
            text, fields: Self.fields + NameTemplate.Field.suppliedByTreewise
        ).get()
        let fixed = NameTemplate.folderValues(["Invoices"])
        let matcher = template.matcher(fixed: fixed)
        for name in Self.names {
            #expect(matcher(name) == template.matches(name, fixed: fixed), "\(name)")
        }
    }
}
