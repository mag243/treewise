import Foundation
import Testing
import TreewiseFileSystem
import TreewiseTestSupport
import UniformTypeIdentifiers

/// Files another app offers in a drop, received into an inbox (ADR 0020, 0047).
@Suite struct ProvidedFilesTests {
    @Test func receivesTheFileAProviderOffers() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Elsewhere")
        let source = try directory.makeFile("Elsewhere/Report.pdf", contents: "report")
        let inbox = try directory.makeFolder("Inbox")
        let provider = try #require(NSItemProvider(contentsOf: source))

        let received = await ProvidedFiles.receive([provider], into: inbox)

        #expect(received.map(\.lastPathComponent) == ["Report.pdf"])
        let copy = try String(contentsOf: try #require(received.first), encoding: .utf8)
        #expect(copy == "report")
        #expect(FileManager.default.fileExists(atPath: source.path), "the source stays")
    }

    @Test func receivesEveryFileOfADrop() async throws {
        let directory = try TempDirectory()
        try directory.makeFolder("Elsewhere")
        let first = try directory.makeFile("Elsewhere/a.txt", contents: "a")
        let second = try directory.makeFile("Elsewhere/b.txt", contents: "b")
        let inbox = try directory.makeFolder("Inbox")
        let providers = try [first, second].map { try #require(NSItemProvider(contentsOf: $0)) }

        let received = await ProvidedFiles.receive(providers, into: inbox)

        #expect(Set(received.map(\.lastPathComponent)) == ["a.txt", "b.txt"])
    }

    /// As the Files app offers a file: its contents with its name, without its URL.
    @Test func namesAFileAsItsProviderSays() async throws {
        let directory = try TempDirectory()
        let source = try directory.makeFile("temporary-1234", contents: "pdf")
        let inbox = try directory.makeFolder("Inbox")
        let provider = NSItemProvider()
        provider.suggestedName = "Report"
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.pdf.identifier, visibility: .all
        ) { completion in
            completion(source, false, nil)
            return nil
        }

        let received = await ProvidedFiles.receive([provider], into: inbox)

        #expect(received.map(\.lastPathComponent) == ["Report.pdf"])
    }

    @Test func aProviderWithoutAFileGivesNothing() async throws {
        let directory = try TempDirectory()
        let inbox = try directory.makeFolder("Inbox")
        let provider = NSItemProvider(object: "only text" as NSString)

        #expect(await ProvidedFiles.receive([provider], into: inbox).isEmpty)
    }
}
