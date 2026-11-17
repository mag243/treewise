import Foundation

/// Hears of a folder's changes the way the system tells file presenters (ADR 0120): an
/// item in it appearing, changing or moving, as a cloud provider reports through file
/// coordination on the iPad, which a descriptor watch may not see. The folder itself
/// going away is left to the descriptor watch, which hears it once it has happened.
///
/// It only listens and never makes a writer wait for it; still, iOS asks that it be
/// removed with `NSFileCoordinator.removeFilePresenter(_:)` while the app is in the
/// background.
public final class FolderPresenter: NSObject, NSFilePresenter, Sendable {
    public let presentedItemURL: URL?
    public let presentedItemOperationQueue: OperationQueue
    private let onChange: @Sendable () -> Void

    /// Creates a presenter of `folder`; `onChange` runs when an item in it changes.
    public init(folder: URL, onChange: @escaping @Sendable () -> Void) {
        presentedItemURL = folder
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        presentedItemOperationQueue = queue
        self.onChange = onChange
    }

    public func presentedSubitemDidAppear(at url: URL) {
        onChange()
    }

    public func presentedSubitemDidChange(at url: URL) {
        onChange()
    }

    public func presentedSubitem(at oldURL: URL, didMoveTo newURL: URL) {
        onChange()
    }

    public func presentedItemDidChange() {
        onChange()
    }
}
