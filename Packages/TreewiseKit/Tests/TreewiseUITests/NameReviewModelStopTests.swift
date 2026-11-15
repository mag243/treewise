import Foundation
import Testing
import TreewiseCore
import TreewiseModuleInterface
import TreewiseTestSupport
import TreewiseUI

/// Closing the overview stops every round of questions to the add-ons, also those that
/// wait for one before them.
extension NameReviewModelTests {
    /// How many files an add-on that reads names is asked about at once (ADR 0073).
    private static let openAtOnce = 4

    @Test func asksNothingMoreOnceStopped() async {
        await store.save(
            FolderSettings(enabledModules: [Self.free], templates: [:]), forFolderAt: "review")
        for number in 1...10 { _ = addFile("scan \(number).pdf") }
        let host = host(
            modules: [Self.freeDescription, Self.paidDescription],
            answers: [
                Self.free: .success([["text": .text("New")]]),
                Self.paid: .success([["company": .text("Acme")]]),
            ])
        host.holdAllAnswers()
        let model = await model(host, waitingUntilRead: false)
        #expect(await eventually { host.requests.count == Self.openAtOnce })

        await model.setModule(Self.paid, on: true)
        model.stop()
        host.releaseAnswers()

        _ = await eventually { host.requests.count > Self.openAtOnce }
        #expect(host.requests.count == Self.openAtOnce)
        #expect(await eventually { model.readingCount == 0 })
    }
}
