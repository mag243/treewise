import Testing
import TreewiseCore
import TreewiseFreeModule
import TreewiseModuleInterface

/// The free module fills in what it knows without reading contents (ADR 0057).
@Suite struct FreeModuleTests {
    private let module = FreeModule()

    private func request(
        _ name: String, date: SuggestedDate? = nil, siblings: [String] = []
    ) -> NameRequest {
        NameRequest(
            id: "1", name: name, contentType: "public.data", byteCount: nil, created: nil,
            modified: nil, suggestedDate: date, siblingNames: siblings, content: ModuleContent())
    }

    private func values(_ request: NameRequest) async throws -> [String: NameTemplate.Value] {
        try #require(try await module.fieldValues(for: request).first)
    }

    @Test func asksForNoContent() {
        #expect(module.description.neededContent.isEmpty)
    }

    @Test func handlesEveryItem() {
        #expect(module.description.contentTypes == ["public.item"])
    }

    @Test func itsDefaultTemplateParses() throws {
        #expect(throws: Never.self) {
            try NameTemplate.parse(
                module.description.defaultTemplate, fields: module.description.fields + [.folder]
            ).get()
        }
    }

    @Test func usesTheDateTheFileSuggests() async throws {
        let date = SuggestedDate(year: 2026, month: 11, day: 2, source: .insideFile)
        #expect(try await values(request("notes.txt", date: date))["date"] == date.value)
    }

    @Test func hasNoDateWithoutASuggestion() async throws {
        #expect(try await values(request("notes.txt"))["date"] == nil)
    }

    @Test(arguments: [
        ("notes.txt", "notes"), ("2026.11.02 Meeting notes.txt", "Meeting notes"),
        ("2026-11-02 - Meeting.txt", "Meeting"), ("Meeting_notes.txt", "Meeting notes"),
        ("a  b.txt", "a b"),
    ])
    func keepsTheMeaningfulPartOfTheName(_ name: String, _ text: String) async throws {
        #expect(try await values(request(name))["text"] == .text(text))
    }

    @Test(arguments: [
        "scan0041.pdf", "Scan 12.pdf", "IMG_2291.heic", "Document.pdf", "invoice(3).pdf",
        "Untitled.pdf", "Screenshot 2026-11-02.png", "document (2).pdf", "12345.pdf",
    ])
    func leavesTextEmptyWhenANameSaysNothing(_ name: String) async throws {
        #expect(try await values(request(name))["text"] == nil)
    }

    @Test func numbersAfterTheHighestSibling() async throws {
        let request = request("new.pdf", siblings: ["Scan 12.pdf", "Scan 13.pdf", "Other.pdf"])
        #expect(try await values(request)["number"] == .text("14"))
    }

    @Test func keepsTheWidthOfNumbers() async throws {
        let request = request("new.pdf", siblings: ["Scan 007.pdf", "Scan 009.pdf"])
        #expect(try await values(request)["number"] == .text("010"))
    }

    @Test func startsNumberingAtOne() async throws {
        #expect(try await values(request("new.pdf"))["number"] == .text("1"))
    }

    @Test func ignoresDatesWhenNumbering() async throws {
        let request = request("new.pdf", siblings: ["2026.11.02 Notes.pdf"])
        #expect(try await values(request)["number"] == .text("1"))
    }

    @Test func derivesATemplateFromNames() {
        #expect(
            module.derivedTemplate(fromNames: ["Scan 1.pdf", "Scan 2.pdf", "Scan 3.pdf"])
                == "Scan {number}")
    }
}
