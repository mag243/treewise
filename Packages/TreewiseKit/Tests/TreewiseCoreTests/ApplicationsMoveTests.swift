import Testing
import TreewiseCore

/// When Treewise offers to move itself to Applications, and where it goes (ADR 0034).
@Suite struct ApplicationsMoveTests {
    private let folders = ApplicationsMove.Folders(
        system: "/Applications", user: "/Users/someone/Applications")

    @Test(arguments: [
        "/Users/someone/Downloads/Treewise.app",
        "/private/var/folders/x1/T/AppTranslocation/2F3A/d/Treewise.app",
        "/Volumes/Treewise/Treewise.app",
        "/Applications Old/Treewise.app",
    ])
    func offersToMoveFromOutsideApplications(_ path: String) {
        #expect(ApplicationsMove.shouldOffer(appPath: path, folders: folders, declined: false))
    }

    @Test(arguments: [
        "/Applications/Treewise.app",
        "/Applications/Utilities/Treewise.app",
        "/applications/Treewise.app",
        "/Users/someone/Applications/Treewise.app",
        "/Applications/../Applications/Treewise.app",
    ])
    func doesNotOfferInsideApplications(_ path: String) {
        #expect(!ApplicationsMove.shouldOffer(appPath: path, folders: folders, declined: false))
    }

    @Test func doesNotOfferAgainOnceDeclined() {
        #expect(
            !ApplicationsMove.shouldOffer(
                appPath: "/Users/someone/Downloads/Treewise.app", folders: folders, declined: true))
    }

    @Test func movesToTheSystemFolderWhenItIsWritable() {
        #expect(
            ApplicationsMove.destinationFolder(folders, systemIsWritable: true) == "/Applications")
    }

    @Test func movesToTheUserFolderWhenTheSystemFolderIsNotWritable() {
        #expect(
            ApplicationsMove.destinationFolder(folders, systemIsWritable: false)
                == "/Users/someone/Applications")
    }
}
