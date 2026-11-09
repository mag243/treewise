import Foundation
import Testing
import TreewiseCore
import TreewiseUI

/// What a drag says over an archive (ADR 0076).
@Suite struct ArchiveDragSessionTests {
    private static let english = Locale(identifier: "en")
    private static let top = ArchivePath(archive: "/d/a.rar")
    private let disk = VolumeID("disk")

    private var target: FileItem {
        FileItem(
            id: Self.top.id, name: "a.rar", kind: .folder, parentID: "/d",
            volume: Self.top.volume)
    }

    private var session: DragSession {
        DragSession(
            items: [FileItem(id: "/d/n.txt", name: "n.txt", kind: .file, volume: disk)],
            ancestry: { _ in [] })
    }

    @Test func aDragOverAnArchiveTellsWhyItCannotDrop() {
        #expect(session.badge(over: target, modifiers: []) == nil)
        #expect(
            session.refusalText(over: target, locale: Self.english)
                == "An archive of this kind can’t be changed. Extract it first.")
    }

    @Test func aDragOverAFolderHasNoReason() {
        let folder = FileItem(id: "/e", name: "e", kind: .folder, volume: disk)
        #expect(session.refusalText(over: folder, locale: Self.english) == nil)
    }

    @Test func promisedFilesDoNotDropIntoAnArchive() {
        #expect(DragSession.promisedBadge(over: target) == nil)
    }
}
