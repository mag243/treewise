import Foundation

/// A uniquely named folder under the system's temporary directory, removed
/// again when the instance goes away. File system tests create and delete
/// files only in here, never in the user's folders.
public final class TempDirectory {
    /// The folder's URL.
    public let url: URL

    /// Creates an empty, uniquely named folder.
    ///
    /// - Throws: when the folder cannot be created.
    public init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Treewise-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// The folder's path, as `LocalFileSystem` uses it for identities.
    public var path: String { url.path }

    /// Returns the URL of a path relative to the folder.
    public func url(_ relativePath: String) -> URL {
        url.appendingPathComponent(relativePath)
    }

    /// Creates a folder, and its missing parents, at a relative path.
    @discardableResult
    public func makeFolder(_ relativePath: String) throws -> URL {
        let folder = url(relativePath)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Writes a file with some contents at a relative path.
    @discardableResult
    public func makeFile(_ relativePath: String, contents: String = "") throws -> URL {
        let file = url(relativePath)
        try Data(contents.utf8).write(to: file)
        return file
    }

    /// Creates a symbolic link at a relative path that points to another one.
    @discardableResult
    public func makeSymlink(_ relativePath: String, to destination: String) throws -> URL {
        let link = url(relativePath)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: url(destination))
        return link
    }
}
