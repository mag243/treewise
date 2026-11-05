import Foundation
import Testing
import TreewiseModuleInterface

/// A request must survive the trip to the module's process (ADR 0057).
@Suite struct NameRequestTests {
    @Test func aRequestSurvivesEncoding() throws {
        let request = NameRequest(
            id: "1", name: "scan.pdf", contentType: "com.adobe.pdf", byteCount: 12,
            created: Date(timeIntervalSince1970: 1), modified: nil, siblingNames: ["a.pdf"],
            content: ModuleContent(
                text: "Invoice",
                positionedText: [
                    PositionedText(
                        text: "Invoice", page: 0, x: 0.1, y: 0.2, width: 0.3, height: 0.4)
                ],
                pageImages: [Data([1, 2])]))
        let decoded = try JSONDecoder().decode(
            NameRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded == request)
    }

    @Test func contentHoldsNothingUnlessGiven() {
        let content = ModuleContent()
        #expect(content.text == nil)
        #expect(content.positionedText == nil)
        #expect(content.pageImages == nil)
    }
}
