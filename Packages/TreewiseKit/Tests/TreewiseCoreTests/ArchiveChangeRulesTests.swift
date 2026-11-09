import Testing

@testable import TreewiseCore

/// What can change inside an archive, by the archive's format (ADR 0078).
@Suite struct ArchiveChangeRulesTests {
    private static let disk = VolumeID("disk")
    private static let zip = ArchivePath(archive: "/d/a.zip")
    private static let other = ArchivePath(archive: "/d/b.zip")
    private static let rar = ArchivePath(archive: "/d/a.rar")

    private static func entry(_ top: ArchivePath, _ path: String, kind: ItemKind = .file)
        -> FileItem
    {
        let place = top.child(path)
        return FileItem(
            id: place.id, name: place.name, kind: kind, parentID: place.parent,
            volume: place.volume)
    }

    private static func top(_ place: ArchivePath) -> FileItem {
        ArchiveTree.topLevelItem(of: place)
    }

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
        ("a.zip", true), ("A.ZIP", true), ("a.tar", true), ("a.tar.gz", true), ("a.tgz", true),
        ("a.tar.bz2", true), ("a.tar.xz", true), ("a.7z", true), ("a.rar", false),
        ("a.iso", false), ("a.cpio", false), ("a.xar", false),
    ])
    func aFormatCanChangeOrNot(name: String, changes: Bool) {
        #expect(ArchiveNaming.canChange(name: name) == changes)
        #expect(ArchivePath(archive: FileItem.ID("/d/" + name)).isChangeable == changes)
    }

    @Test func anEntryOfAChangeableArchiveIsLikeAnItemOnDisk() {
        let file = Self.entry(Self.zip, "x.txt")
        #expect(file.isCopyable)
        #expect(file.isMovable)
        #expect(file.canBeRenamedOrTrashed)
        #expect(Self.entry(Self.zip, "f", kind: .folder).acceptsItems)
    }

    @Test func theTopLevelTakesItemsButIsNoItemToChange() {
        let top = Self.top(Self.zip)
        #expect(top.acceptsItems)
        #expect(!top.isMovable)
        #expect(!top.canBeRenamedOrTrashed)
    }

    @Test func aFileInAnArchiveTakesNothing() {
        #expect(!Self.entry(Self.zip, "x.txt").acceptsItems)
    }

    @Test func aReadOnlyArchiveStaysReadOnly() {
        let file = Self.entry(Self.rar, "x.txt")
        #expect(file.isCopyable)
        #expect(!file.isMovable)
        #expect(!file.canBeRenamedOrTrashed)
        #expect(!Self.top(Self.rar).acceptsItems)
        #expect(!Self.entry(Self.rar, "f", kind: .folder).acceptsItems)
    }

    @Test(arguments: [DropModifiers(), .option, .command])
    func whatComesInFromDiskIsCopied(modifiers: DropModifiers) {
        #expect(plan([Self.diskFile], onto: Self.top(Self.zip), modifiers: modifiers) == .copy)
    }

    @Test(arguments: [DropModifiers(), .option, .command])
    func whatComesFromAnotherArchiveIsCopied(modifiers: DropModifiers) {
        #expect(
            plan([Self.entry(Self.other, "x")], onto: Self.top(Self.zip), modifiers: modifiers)
                == .copy)
    }

    @Test(arguments: [DropModifiers(), .option, .command])
    func goingOutIsCopying(modifiers: DropModifiers) {
        #expect(
            plan([Self.entry(Self.zip, "x")], onto: Self.diskFolder, modifiers: modifiers) == .copy)
    }

    @Test func withinAnArchiveADragMoves() {
        let target = Self.entry(Self.zip, "f", kind: .folder)
        #expect(plan([Self.entry(Self.zip, "x")], onto: target) == .move)
        #expect(plan([Self.entry(Self.zip, "x")], onto: target, modifiers: .command) == .move)
    }

    @Test func withinAnArchiveOptionCopies() {
        let target = Self.entry(Self.zip, "f", kind: .folder)
        #expect(plan([Self.entry(Self.zip, "x")], onto: target, modifiers: .option) == .copy)
    }

    @Test func aMoveOntoWhereItAlreadyIsDoesNotDrop() {
        #expect(plan([Self.entry(Self.zip, "x")], onto: Self.top(Self.zip)) == nil)
    }

    @Test func nothingDropsIntoAReadOnlyArchive() {
        #expect(plan([Self.diskFile], onto: Self.top(Self.rar)) == nil)
        #expect(TransferPlanner.refusal(target: Self.top(Self.rar)) == .archiveReadOnly)
    }

    @Test func aChangeableArchiveHasNoReasonToRefuse() {
        #expect(TransferPlanner.refusal(target: Self.top(Self.zip)) == nil)
    }

    @Test func aCutItemLeavingItsArchiveIsCopied() {
        let entry = Self.entry(Self.zip, "x")
        #expect(TransferPlanner.pasteMode(of: [entry], onto: Self.diskFolder, cut: true) == .copy)
        #expect(
            TransferPlanner.pasteMode(of: [Self.diskFile], onto: Self.top(Self.zip), cut: true)
                == .copy)
    }

    @Test func aCutItemWithinItsArchiveMoves() {
        let entry = Self.entry(Self.zip, "x")
        let target = Self.entry(Self.zip, "f", kind: .folder)
        #expect(TransferPlanner.pasteMode(of: [entry], onto: target, cut: true) == .move)
    }

    @Test func aCutItemOnDiskMovesAndACopiedOneCopies() {
        #expect(
            TransferPlanner.pasteMode(of: [Self.diskFile], onto: Self.diskFolder, cut: true)
                == .move)
        #expect(
            TransferPlanner.pasteMode(of: [Self.diskFile], onto: Self.diskFolder, cut: false)
                == .copy)
    }
}
