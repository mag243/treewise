import Testing
import TreewiseCore

@Suite struct ItemKindTests {
    @Test(arguments: [ItemKind.folder, .volume, .cloud])
    func containersAcceptDrops(_ kind: ItemKind) {
        #expect(kind.isContainer)
    }

    @Test(arguments: [ItemKind.file, .package])
    func filesAndPackagesAreNotContainers(_ kind: ItemKind) {
        #expect(!kind.isContainer)
    }

    @Test(arguments: [ItemKind.folder, .file, .package])
    func foldersFilesAndPackagesCanBeMoved(_ kind: ItemKind) {
        #expect(kind.isMovable)
    }

    @Test(arguments: [ItemKind.volume, .cloud, .home])
    func locationsCannotBeMoved(_ kind: ItemKind) {
        #expect(!kind.isMovable)
    }

    @Test(arguments: [ItemKind.folder, .file, .package, .volume])
    func itemsCanBeRenamedAndTrashed(_ kind: ItemKind) {
        #expect(kind.canBeRenamedOrTrashed)
    }

    @Test(arguments: [ItemKind.cloud, .home, .computer])
    func cloudLocationsHomeAndThisMacCannotBeRenamedOrTrashed(_ kind: ItemKind) {
        #expect(!kind.canBeRenamedOrTrashed)
    }

    @Test func thisMacOpensLikeAFolder() {
        #expect(ItemKind.computer.isContainer)
    }

    @Test(arguments: [ItemKind.folder, .volume, .cloud])
    func foldersAndLocationsTakeItems(_ kind: ItemKind) {
        #expect(kind.acceptsItems)
    }

    @Test(arguments: [ItemKind.computer, .file, .package])
    func thisMacFilesAndPackagesTakeNoItems(_ kind: ItemKind) {
        #expect(!kind.acceptsItems)
    }

    @Test func thisMacCannotBeMoved() {
        #expect(!ItemKind.computer.isMovable)
    }
}
