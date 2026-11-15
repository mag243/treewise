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
        Self.grantOwnerWrite(under: url)
        try? FileManager.default.removeItem(at: url)
    }

    /// Lets the owner write in every folder below `folder`, as one extracted from a disk
    /// image is read-only and its items could not be removed otherwise. Symbolic links
    /// are left alone, as a permission set through one would change what it points to.
    private static func grantOwnerWrite(under folder: URL) {
        let manager = FileManager.default
        let below = (try? manager.subpathsOfDirectory(atPath: folder.path)) ?? []
        let folders = [folder] + below.map { folder.appendingPathComponent($0) }
        for candidate in folders {
            guard
                let attributes = try? manager.attributesOfItem(atPath: candidate.path),
                attributes[.type] as? FileAttributeType == .typeDirectory,
                let permissions = attributes[.posixPermissions] as? Int
            else { continue }
            try? manager.setAttributes(
                [.posixPermissions: permissions | ownerAll], ofItemAtPath: candidate.path)
        }
    }

    /// Read, write and search for the owner.
    private static let ownerAll = 0o700

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

    /// Moves the folder at `path` to `name` in this directory, and gives its new path.
    @discardableResult
    public func moveFolder(atPath path: String, to name: String) throws -> String {
        let target = url(name).path
        try FileManager.default.moveItem(atPath: path, toPath: target)
        return target
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
