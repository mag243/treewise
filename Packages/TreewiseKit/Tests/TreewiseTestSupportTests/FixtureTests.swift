import Foundation
import Testing
import TreewiseCore
import TreewiseTestSupport

@Suite struct FixtureTests {
    let fileSystem = Fixture.standard

    @Test func hasTheThreeLocationsOfThePrototype() {
        let locations = fileSystem.items.filter { $0.parentID == nil }.map(\.id)
        #expect(Set(locations) == ["hd", "icloud", "usb"])
    }

    @Test func putsEveryItemOnTheVolumeOfItsLocation() throws {
        #expect(try #require(fileSystem["s1"]).volume == "hd")
        #expect(try #require(fileSystem["sc1"]).volume == "icloud")
        #expect(try #require(fileSystem["v1"]).volume == "usb")
    }

    @Test func modelsApplicationsAsPackagesWithTheirExtension() throws {
        let safari = try #require(fileSystem["a1"])
        #expect(safari.name == "Safari.app")
        #expect(safari.kind == .package)
    }

    @Test func givesFoldersNoSizeAndFilesTheirSize() throws {
        #expect(try #require(fileSystem["documents"]).size == nil)
        #expect(try #require(fileSystem["doc2"]).size == 6100)
    }

    @Test func datesTodayAndYesterdayRelativeToTheFixtureClock() throws {
        let calendar = Fixture.calendar
        let todo = try #require(fileSystem["d2"]?.modified)
        let screenshot = try #require(fileSystem["d1"]?.modified)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: Fixture.now))
        #expect(calendar.isDate(todo, inSameDayAs: Fixture.now))
        #expect(calendar.isDate(screenshot, inSameDayAs: yesterday))
    }
}
