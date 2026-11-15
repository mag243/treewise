import Testing
import TreewiseCore
import TreewiseUI

/// "Apply to All" for the name conflicts of one operation (PLAN.md §4.2).
@MainActor
@Suite struct AskingConflictResolverTests {
    private final class Asked {
        var names: [String] = []
    }

    private func item(_ name: String) -> FileItem {
        FileItem(id: FileItem.ID("/a/" + name), name: name, kind: .file, volume: "disk")
    }

    private func resolver(
        answering answers: [AskingConflictResolver.Answer], asked: Asked
    ) -> AskingConflictResolver {
        var left = answers
        return AskingConflictResolver { item in
            asked.names.append(item.name)
            return left.removeFirst()
        }
    }

    @Test func asksAboutEachConflictUntilAnAnswerAppliesToAll() async {
        let asked = Asked()
        let resolver = resolver(
            answering: [
                .init(decision: .replace, appliesToAll: false),
                .init(decision: .keepBoth, appliesToAll: false),
            ], asked: asked)
        #expect(await resolver.decide(existing: item("a"), incoming: item("a")) == .replace)
        #expect(await resolver.decide(existing: item("b"), incoming: item("b")) == .keepBoth)
        #expect(asked.names == ["a", "b"])
    }

    @Test func anAnswerForAllIsGivenWithoutAskingAgain() async {
        let asked = Asked()
        let resolver = resolver(
            answering: [.init(decision: .keepBoth, appliesToAll: true)], asked: asked)
        #expect(await resolver.decide(existing: item("a"), incoming: item("a")) == .keepBoth)
        #expect(await resolver.decide(existing: item("b"), incoming: item("b")) == .keepBoth)
        #expect(await resolver.decide(existing: item("c"), incoming: item("c")) == .keepBoth)
        #expect(asked.names == ["a"])
    }

    @Test func stopForAllStopsTheRest() async {
        let asked = Asked()
        let resolver = resolver(
            answering: [.init(decision: .stop, appliesToAll: true)], asked: asked)
        #expect(await resolver.decide(existing: item("a"), incoming: item("a")) == .stop)
        #expect(await resolver.decide(existing: item("b"), incoming: item("b")) == .stop)
    }

    @Test func asksAboutTheIncomingItem() async {
        let asked = Asked()
        let resolver = resolver(
            answering: [.init(decision: .replace, appliesToAll: false)], asked: asked)
        _ = await resolver.decide(existing: item("old.txt"), incoming: item("new.txt"))
        #expect(asked.names == ["new.txt"])
    }
}
