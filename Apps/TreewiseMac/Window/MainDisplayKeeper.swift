import AppKit

/// In a run for UI tests or screenshots (`-TreewiseRoot`, `-TreewiseWindowSize`), every
/// window opens on the main display, the one with the menu bar. AppKit opens a window on
/// the display the user works on, and XCTest cannot take a screenshot of a window on
/// another display than the main one, so a test run would depend on where the pointer
/// was. A window is moved when it first becomes key, which covers windows AppKit makes
/// itself, such as the About panel.
@MainActor
final class MainDisplayKeeper: NSObject {
    private static var shared: MainDisplayKeeper?

    /// Starts keeping windows on the main display, in a test run only.
    static func startIfTestRun() {
        guard LaunchOptions.isTestRun, shared == nil else { return }
        let keeper = MainDisplayKeeper()
        shared = keeper
        NotificationCenter.default.addObserver(
            keeper, selector: #selector(windowBecameKey(_:)),
            name: NSWindow.didBecomeKeyNotification, object: nil)
    }

    @objc private func windowBecameKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, !window.isSheet,
            let main = NSScreen.screens.first, window.screen?.frame != main.frame
        else { return }
        let display = main.visibleFrame
        window.setFrameOrigin(
            CGPoint(
                x: display.midX - window.frame.width / 2,
                y: display.midY - window.frame.height / 2))
    }
}
