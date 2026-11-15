import Foundation
import Testing
import TreewiseCore

/// Any error, as the window shows it (ADR 0018).
@Suite struct FileSystemErrorTests {
    @Test func keepsAFileSystemError() {
        #expect(FileSystemError(FileSystemError.notFound("a")) == .notFound("a"))
    }

    @Test func describesAnyOtherError() {
        let error = CocoaError(.fileWriteUnknown)
        #expect(FileSystemError(error) == .unexpected(error.localizedDescription))
    }
}
