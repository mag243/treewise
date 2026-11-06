import Testing
import TreewiseCore
import TreewiseFolderPatternModule
import TreewiseModuleInterface

/// The folder pattern module fills in what it knows without reading contents (ADR 0057).
@Suite struct FolderPatternModuleTests {
    private let module = FolderPatternModule()

    private func request(
        _ name: String, date: SuggestedDate? = nil, siblings: [String] = [],
        folder: String = "Holiday 2026"
    ) -> NameRequest {
        NameRequest(
            id: "1", name: name, contentType: "public.data", byteCount: nil, created: nil,
            modified: nil, suggestedDate: date, siblingNames: siblings, content: ModuleContent(),
            folderName: folder)
    }

    private func values(_ request: NameRequest) async throws -> [String: NameTemplate.Value] {
        try #require(try await module.fieldValues(for: request).first)
    }

    @Test func asksForNoContent() {
        #expect(module.description.neededContent.isEmpty)
    }

    @Test func isFree() {
        #expect(module.description.isFree)
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

    /// A number from the file is a field of modules that read files; the next number of
    /// a series is Treewise's `{seq}` (ADR 0067).
    @Test func fillsInTheDateAndTheTextOnly() {
        #expect(module.description.fields.map(\.name) == ["date", "text"])
    }

    @Test(arguments: [
        ("2026.08.14 - Holiday 2026 - c.heic", "c"),
        ("2026.08.14 - Holiday 202 - c.heic", "c"),
        ("2026.08.14 - holliday 2026 - c.heic", "c"),
        ("2026.08.14 Holiday - c.heic", "c"),
        ("Holiday 2026_c.heic", "c"),
        ("c - Holiday 2026.heic", "c"),
        ("2026.08.14 - Holiday 2025 - c.heic", "Holiday 2025 - c"),
        ("Holiday photos at the beach.heic", "Holiday photos at the beach"),
    ])
    func leavesTheFolderNameOutOfTheText(_ name: String, _ text: String) async throws {
        #expect(try await values(request(name))["text"] == .text(text))
    }

    @Test func hasNoTextWhenTheNameIsOnlyTheFolderName() async throws {
        #expect(try await values(request("2026.08.14 Holiday 2026.heic"))["text"] == nil)
    }

    @Test func derivesATemplateFromNames() {
        #expect(
            module.derivedTemplate(
                fromNames: ["Scan 1.pdf", "Scan 2.pdf", "Scan 3.pdf"], folderName: "Scans")
                == "Scan {seq}")
    }
}
