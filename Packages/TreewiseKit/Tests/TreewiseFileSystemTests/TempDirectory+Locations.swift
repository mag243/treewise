import Foundation
import TreewiseFileSystem
import TreewiseTestSupport

/// A home folder and an Applications folder inside a test's directory, so a test never
/// reaches the user's own.
extension TempDirectory {
    var locations: LocalFileSystem.Locations {
        .init(home: url("home"), applications: url("Applications"))
    }

    /// A runner of file operations in this directory.
    var runner: FileOperationRunner { FileOperationRunner(locations: locations) }

    /// The local disk as seen from this directory.
    var fileSystem: LocalFileSystem { LocalFileSystem(locations: locations) }
}
