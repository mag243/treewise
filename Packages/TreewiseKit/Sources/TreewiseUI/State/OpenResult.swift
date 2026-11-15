import TreewiseCore

/// What opening an item did.
public enum OpenResult: Sendable, Equatable {
    /// A folder opened in the browser.
    case navigated
    /// A file, which the app opens in its default application.
    case openFile(FileItem)
}
