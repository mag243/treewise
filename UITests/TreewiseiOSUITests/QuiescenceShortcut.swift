import ObjectiveC
import XCTest

/// A fixed pause in place of XCUITest's wait for the app to come to rest, for the UI review
/// on iPadOS 27 and later only (ADR 0115).
///
/// On the iPadOS 27 simulator XCUITest often stops reporting an app idle after text input or
/// while a context menu is open, Apple's apps too, and waits a minute before every step. The
/// walk only looks at screens, so a short pause serves it: XCUITest's own switches to skip
/// the check before and after an event (`shouldSkipPreEventQuiescence`,
/// `shouldSkipPostEventQuiescence` of the private `XCUIApplicationProcess`) answer yes after
/// it. Should a newer Xcode rename them, nothing is changed and the review waits as before,
/// which `idle.py` reports.
///
/// TODO: remove once Apple fixes the waits on iPadOS 27 (reported in Feedback Assistant).
enum QuiescenceShortcut {
    /// The pause in place of the wait, long enough for a sheet or menu to settle.
    static let pause: TimeInterval = 0.5
    /// The first iOS the waits happen on.
    private static let firstMajorVersion = 27
    private static let selectors = [
        "shouldSkipPreEventQuiescence", "shouldSkipPostEventQuiescence",
    ]
    @MainActor private static var isInstalled = false

    /// Installs the pause, once, where the iOS the tests run on needs it.
    @MainActor
    static func installIfNeeded() {
        guard !isInstalled,
            ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= firstMajorVersion,
            let process = NSClassFromString("XCUIApplicationProcess")
        else { return }
        isInstalled = true
        let skip: @convention(block) (AnyObject) -> Bool = { _ in
            Thread.sleep(forTimeInterval: pause)
            return true
        }
        let implementation = imp_implementationWithBlock(skip)
        for name in selectors {
            guard let method = class_getInstanceMethod(process, NSSelectorFromString(name))
            else { continue }
            method_setImplementation(method, implementation)
        }
    }
}
