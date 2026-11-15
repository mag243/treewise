import Testing
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// What kept the review from proposing names, and trying again.
extension NameReviewModelTests {
    @Test func saysWhenTheFolderCannotBeRead() async {
        _ = addFile("scan.txt")
        fileSystem.remove(folder.id)
        let model = await model(host())
        #expect(model.startProblem == .folderUnreadable)
    }

    @Test func saysWhenTheAddOnsCannotBeReached() async {
        _ = addFile("scan.txt")
        let host = host()
        host.failAvailableModules()
        let model = await model(host)
        #expect(model.startProblem == .addOnsUnavailable)
    }

    @Test func readsTheAddOnsAgainWhenAskedToTryAgain() async {
        let item = addFile("scan.txt")
        let host = host()
        host.failAvailableModules()
        let model = await model(host)
        host.reachAvailableModules()
        await model.retry()
        await model.waitUntilRead()
        #expect(model.startProblem == nil)
        #expect(model.session?.entry(item.id)?.proposals.isEmpty == false)
    }

    @Test func asksAModuleThatGaveNoAnswerAgainWhenAskedToTryAgain() async {
        _ = addFile("scan.txt")
        let host = host(answers: [Self.free: .failure(.unavailable)])
        let model = await model(host)
        let asked = host.requests.count
        await model.retry()
        await model.waitUntilRead()
        #expect(host.requests.count > asked)
    }

    @Test func hasNoProblemWhenAllIsRead() async {
        _ = addFile("scan.txt")
        #expect(await model(host()).startProblem == nil)
    }
}
