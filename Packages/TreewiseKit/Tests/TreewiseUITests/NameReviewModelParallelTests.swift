import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// The overview asks the add-ons in parallel, within limits (ADR 0073). The host holds its
/// answers back until as many requests are open as the limits allow.
extension NameReviewModelTests {
    private func addFiles(_ count: Int, ending: String) -> [FileItem] {
        (1...count).map { addFile("scan \($0).\(ending)") }
    }

    private func turnOn(_ ids: [String]) async {
        await store.save(FolderSettings(enabledModules: ids, templates: [:]), forFolderAt: "review")
    }

    private func bothModules() -> ScriptedModuleHost {
        host(
            modules: [Self.freeDescription, Self.paidDescription],
            answers: [
                Self.free: .success([["text": .text("New")]]),
                Self.paid: .success([["company": .text("Acme")]]),
            ])
    }

    @Test
    func asksAnAddOnThatReadsNamesForFourFilesAtOnce() async {
        let files = addFiles(10, ending: "txt")
        let host = host()
        host.holdAnswers(untilOpen: 4, total: files.count)
        let model = await model(host)
        #expect(host.mostOpenAtOnce[Self.free] == 4)
        #expect(model.readingCount == 0)
        #expect(files.allSatisfy { model.session?.entry($0.id)?.currentName != nil })
    }

    @Test
    func asksAnAddOnThatReadsContentsForTwoFilesAtOnce() async {
        await turnOn([Self.paid])
        let files = addFiles(5, ending: "pdf")
        let host = bothModules()
        host.holdAnswers(untilOpen: 2, total: files.count)
        _ = await model(host)
        #expect(host.mostOpenAtOnce[Self.paid] == 2)
    }

    @Test
    func asksTheAddOnsAtTheSameTime() async {
        await turnOn([Self.free, Self.paid])
        let files = addFiles(3, ending: "pdf")
        let host = bothModules()
        // All three files for the one that reads names, and two for the one reading contents.
        host.holdAnswers(untilOpen: 5, total: 2 * files.count)
        _ = await model(host)
        #expect(host.mostOpenAtOnce == [Self.free: 3, Self.paid: 2])
    }

    @Test func asksAboutTheSelectedFileFirst() async {
        await turnOn([Self.free])
        let files = addFiles(4, ending: "pdf")
        let host = bothModules()
        let model = await model(host)
        model.selectedID = files[3].id
        await model.setModule(Self.paid, on: true)
        await model.waitUntilRead()
        let asked = host.askedOrder(of: Self.paid)
        #expect(asked.count == files.count)
        // Two are asked at once, the selected one among the first.
        #expect(asked.prefix(2).contains(files[3].id.rawValue))
    }
}
