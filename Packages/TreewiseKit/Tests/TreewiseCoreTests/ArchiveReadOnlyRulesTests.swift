import Testing

@testable import TreewiseCore

/// What can be done with an item inside an archive (ADR 0076).
@Suite struct ArchiveReadOnlyRulesTests {
    private static let disk = VolumeID("disk")
    private static let archive = ArchivePath(archive: "/d/a.rar")

    private static func entry(_ path: String, kind: ItemKind = .file) -> FileItem {
        let place = ArchivePath(archive: archive.archive, entry: path)
        return FileItem(
            id: place.id, name: place.name, kind: kind, parentID: place.parent,
            volume: place.volume)
    }

    private static let topLevel = FileItem(
        id: archive.id, name: archive.name, kind: .folder, parentID: archive.parent,
        volume: archive.volume)
    private static let diskFile = FileItem(
        id: "/d/note.txt", name: "note.txt", kind: .file, parentID: "/d", volume: disk)
    private static let diskFolder = FileItem(
        id: "/e", name: "e", kind: .folder, parentID: "/", volume: disk)

    private func plan(
        _ items: [FileItem], onto target: FileItem, modifiers: DropModifiers = []
    ) -> TransferMode? {
        TransferPlanner.plan(items: items, target: target, modifiers: modifiers) { _ in [] }
    }

    @Test(arguments: [
        entry("x.txt"), entry("folder", kind: .folder), topLevel,
    ])
    func anItemInsideAnArchiveCanOnlyBeCopied(item: FileItem) {
        #expect(item.isCopyable)
        #expect(!item.isMovable)
        #expect(!item.canBeRenamedOrTrashed)
        #expect(!item.acceptsItems)
    }

    @Test func anItemOnDiskIsNotHeldBack() {
        #expect(Self.diskFile.isCopyable)
        #expect(Self.diskFile.isMovable)
        #expect(Self.diskFile.canBeRenamedOrTrashed)
        #expect(Self.diskFolder.acceptsItems)
    }

    @Test func aVolumeCanBeNeitherCopiedNorMoved() {
        let volume = FileItem(id: "/Volumes/T7", name: "T7", kind: .volume, volume: Self.disk)
        #expect(!volume.isCopyable)
        #expect(!volume.isMovable)
    }

    @Test(arguments: [DropModifiers(), .option, .command])
    func draggingOutCopiesWhateverIsHeld(modifiers: DropModifiers) {
        #expect(plan([Self.entry("x.txt")], onto: Self.diskFolder, modifiers: modifiers) == .copy)
    }

    @Test func aSelectionWithAnEntryCopiesAsAWhole() {
        #expect(
            plan([Self.diskFile, Self.entry("x.txt")], onto: Self.diskFolder, modifiers: .command)
                == .copy)
    }

    @Test func nothingDropsIntoAnArchive() {
        #expect(plan([Self.diskFile], onto: Self.topLevel) == nil)
        #expect(plan([Self.diskFile], onto: Self.entry("folder", kind: .folder)) == nil)
    }

    @Test func nothingDropsFromAnArchiveIntoItself() {
        #expect(plan([Self.entry("x.txt")], onto: Self.entry("folder", kind: .folder)) == nil)
    }

    @Test func aDropIntoAnArchiveIsRefusedWithAReason() {
        #expect(TransferPlanner.refusal(target: Self.topLevel) == .archiveReadOnly)
        #expect(TransferPlanner.refusal(target: Self.entry("f", kind: .folder)) == .archiveReadOnly)
    }

    @Test func aDropOnDiskHasNoSuchReason() {
        #expect(TransferPlanner.refusal(target: Self.diskFolder) == nil)
    }
}
