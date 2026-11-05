import AppKit

/// The `NSWindow` a browser window is in, for code that has to wait until
/// SwiftUI has put the view in one.
@MainActor
final class WindowHost {
    private(set) var window: NSWindow?
    private var waiting: [CheckedContinuation<NSWindow, Never>] = []

    /// Records the window and hands it to everyone waiting for it.
    func set(_ window: NSWindow) {
        self.window = window
        for continuation in waiting { continuation.resume(returning: window) }
        waiting = []
    }

    /// The window, once there is one.
    func awaitWindow() async -> NSWindow {
        if let window { return window }
        return await withCheckedContinuation { waiting.append($0) }
    }
}
