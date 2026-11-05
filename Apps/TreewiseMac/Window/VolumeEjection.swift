import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// Ejects volumes from the sidebar, a context menu or File > Eject (ADR 0044):
/// every window first leaves the volume, so Treewise holds nothing on it,
/// then macOS ejects it; when macOS refuses, an alert says why.
@MainActor
enum VolumeEjection {
    static func eject(_ volumes: [FileItem]) {
        let ejectable = volumes.filter(\.isEjectable)
        guard !ejectable.isEmpty else { return }
        Task {
            for volume in ejectable {
                for browser in WindowTabs.shared.allBrowsers {
                    await browser.leave(volume: volume.id)
                }
                do {
                    try await LocalFileSystem(locations: LaunchOptions.locations).eject(volume.id)
                } catch {
                    show(error as? FileSystemError ?? .notEjected(volume.id, "\(error)"))
                }
            }
        }
    }

    private static func show(_ failure: FileSystemError) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = FailureMessage.text(for: failure, locale: .current)
        alert.runModal()
    }
}
