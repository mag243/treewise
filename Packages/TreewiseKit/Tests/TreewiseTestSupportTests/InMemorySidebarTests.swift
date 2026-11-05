import Testing
import TreewiseCore
import TreewiseTestSupport

/// The sidebar and status bar surface of the in-memory file system (ADR 0016).
@Suite struct InMemorySidebarTests {
    let fileSystem = Fixture.standard

    @Test func listsTheTopLevelLocationsInOrder() async throws {
        let locations = try await fileSystem.locations().map(\.id)
        #expect(locations == ["hd", "icloud", "usb"])
    }

    @Test func listsTheFavoritesOfThePrototypeInItsOrder() async throws {
        let favorites = try await fileSystem.favorites().map(\.name)
        #expect(
            favorites == [
                "Applications", "Desktop", "Documents", "Downloads", "Pictures", "Projects",
            ])
    }

    @Test func reportsTheFreeSpaceOfAFoldersVolume() async throws {
        #expect(try await fileSystem.availableCapacity(of: "documents") == 245_300_000_000)
        #expect(try await fileSystem.availableCapacity(of: "backups") == 612_800_000_000)
    }

    @Test func reportsNoFreeSpaceForAnUnknownFolder() async {
        await #expect(throws: FileSystemError.notFound("nowhere")) {
            try await fileSystem.availableCapacity(of: "nowhere")
        }
    }
}
