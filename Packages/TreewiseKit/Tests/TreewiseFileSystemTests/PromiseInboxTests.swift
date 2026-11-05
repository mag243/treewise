import Foundation
import Testing
import TreewiseFileSystem
import TreewiseTestSupport

/// The hidden folder promised files are received into (ADR 0020).
@Suite struct PromiseInboxTests {
    @Test func makesAHiddenInboxInTheTargetFolder() throws {
        let directory = try TempDirectory()
        let inbox = try PromiseInbox.make(in: directory.url)

        #expect(inbox.deletingLastPathComponent().standardizedFileURL.path == directory.path)
        #expect(inbox.lastPathComponent.hasPrefix("."))
        var isFolder: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: inbox.path, isDirectory: &isFolder))
        #expect(isFolder.boolValue)
    }

    @Test func makesADifferentInboxForEveryDrop() throws {
        let directory = try TempDirectory()
        #expect(try PromiseInbox.make(in: directory.url) != PromiseInbox.make(in: directory.url))
    }

    @Test func discardsTheInboxWithWhatItReceived() throws {
        let directory = try TempDirectory()
        let inbox = try PromiseInbox.make(in: directory.url)
        try Data("attachment".utf8).write(to: inbox.appendingPathComponent("Invoice.pdf"))

        try PromiseInbox.discard(inbox)

        #expect(!FileManager.default.fileExists(atPath: inbox.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    // Exit tests run only where a test can start a process: the Mac.
    #if os(macOS)
        /// The path does not exist, so even without the precondition nothing could be removed.
        @Test func refusesToDiscardAFolderThatIsNoInbox() async {
            await #expect(processExitsWith: .failure) {
                try? PromiseInbox.discard(URL(fileURLWithPath: "/treewise-missing/Documents"))
            }
        }
    #endif
}
