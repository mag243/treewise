import Foundation
import TreewiseFileNamePatternsModule
import TreewiseFileSystem
import TreewiseModuleInterface

/// What the name proposals and folder templates share across the app (ADR 0129): the free
/// module, run inside the app, and the stores of the folders' name settings and of the
/// templates. A UI test's run keeps them apart from the real ones, in its own folder.
@MainActor
enum NameServices {
    /// The free module and no other: the iPad links it directly, not the catalog an
    /// official build fills with the paid ones too.
    static let moduleHost = InProcessModuleHost(modules: [FileNamePatternsModule()])
    static let folderSettings = FolderSettingsStore(directory: directory)
    static let templates = FolderTemplateStore(
        directory: directory.appendingPathComponent("Templates", isDirectory: true))

    /// Where the folder settings and templates are kept.
    private static var directory: URL {
        TestRun.current?.folder.appendingPathComponent("Settings", isDirectory: true)
            ?? FolderSettingsStore.defaultDirectory
    }
}
