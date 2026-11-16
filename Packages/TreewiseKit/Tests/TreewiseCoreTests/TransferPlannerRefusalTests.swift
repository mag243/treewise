import Testing
import TreewiseCore
import TreewiseTestSupport

/// Why a drop is refused, for the iPad's table, which checks a drop when it lands
/// (ADR 0047, amended 2026-11-16): a reason for every drop `plan` refuses, none for one it
/// allows.
@Suite struct TransferPlannerRefusalTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let items: [FileItem.ID]
        let target: FileItem.ID
        let modifiers: DropModifiers
        let refusal: DropRefusal?
        var testDescription: String {
            "\(items) onto \(target) \(modifiers): \(String(describing: refusal))"
        }
    }

    static let cases: [Case] = [
        Case(items: ["projects"], target: "projects", modifiers: [], refusal: .intoItself),
        Case(items: ["projects"], target: "src", modifiers: .option, refusal: .intoItself),
        Case(items: ["doc2"], target: "doc1", modifiers: [], refusal: .notAFolder),
        Case(items: ["doc2"], target: "a1", modifiers: [], refusal: .notAFolder),
        Case(items: ["doc2"], target: "documents", modifiers: [], refusal: .alreadyThere),
        Case(items: ["doc2"], target: "documents", modifiers: .command, refusal: .alreadyThere),
        Case(items: ["doc2"], target: "documents", modifiers: .option, refusal: nil),
        Case(items: ["doc2"], target: "projects", modifiers: [], refusal: nil),
        Case(items: ["doc2", "d2"], target: "documents", modifiers: [], refusal: nil),
    ]

    @Test(arguments: cases)
    func namesWhyADropIsRefused(_ drop: Case) {
        #expect(refusalOfDrag(drop.items, onto: drop.target, drop.modifiers) == drop.refusal)
    }

    @Test(arguments: cases)
    func refusesExactlyWhatThePlanRefuses(_ drop: Case) {
        let planned = planDrag(drop.items, onto: drop.target, drop.modifiers)
        #expect((planned == nil) == (drop.refusal != nil))
    }
}
