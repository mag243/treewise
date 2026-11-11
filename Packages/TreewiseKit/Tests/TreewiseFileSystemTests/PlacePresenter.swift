#if os(macOS)
    import Foundation
    import Synchronization

    /// Presents a file's place as the app a file is promised to does while it
    /// waits for it, and hears whether a writer asks it to give way: a write
    /// that coordinates the place would wait for that app.
    final class PlacePresenter: NSObject, NSFilePresenter {
        let presentedItemURL: URL?
        let presentedItemOperationQueue = OperationQueue()
        private let asked = Mutex(false)

        /// Whether a coordinated write of the place asked this presenter to give way.
        var wasAskedToGiveWay: Bool {
            asked.withLock { $0 }
        }

        init(_ place: URL) {
            presentedItemURL = place
            super.init()
            NSFileCoordinator.addFilePresenter(self)
        }

        /// Stops presenting the place.
        func stop() {
            NSFileCoordinator.removeFilePresenter(self)
        }

        func relinquishPresentedItem(
            toWriter writer: @escaping @Sendable ((@Sendable () -> Void)?) -> Void
        ) {
            asked.withLock { $0 = true }
            writer(nil)
        }
    }
#endif
