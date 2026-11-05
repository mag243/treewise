import Testing
import TreewiseCore

/// The segments of the path bar.
@Suite struct PathComponentsTests {
    private let mounts = [
        MountPoint(path: "/", name: "Macintosh HD"),
        MountPoint(path: "/Volumes/T7", name: "SAMSUNG T7"),
    ]

    private func crumbs(_ path: String) -> [String] {
        PathComponents.breadcrumbs(for: path, mountPoints: mounts).map { "\($0.name)=\($0.path)" }
    }

    @Test func startsAtTheStartupVolume() {
        #expect(
            crumbs("/Users/x/Projects/Treewise") == [
                "Macintosh HD=/", "Users=/Users", "x=/Users/x", "Projects=/Users/x/Projects",
                "Treewise=/Users/x/Projects/Treewise",
            ])
    }

    @Test func startsAtTheVolumeAPathIsOn() {
        #expect(
            crumbs("/Volumes/T7/Backups") == [
                "SAMSUNG T7=/Volumes/T7", "Backups=/Volumes/T7/Backups",
            ])
    }

    @Test func showsOnlyTheVolumeForItsRoot() {
        #expect(crumbs("/") == ["Macintosh HD=/"])
        #expect(crumbs("/Volumes/T7") == ["SAMSUNG T7=/Volumes/T7"])
    }

    @Test func matchesAVolumeByWholeComponents() {
        #expect(
            crumbs("/Volumes/T7X/a") == [
                "Macintosh HD=/", "Volumes=/Volumes", "T7X=/Volumes/T7X", "a=/Volumes/T7X/a",
            ])
    }

    @Test func ignoresTrailingAndDoubleSlashes() {
        #expect(crumbs("//Users//x/") == ["Macintosh HD=/", "Users=/Users", "x=/Users/x"])
    }

    @Test func namesTheRootAfterItselfWithoutAMountPoint() {
        let crumbs = PathComponents.breadcrumbs(for: "/tmp", mountPoints: [])
        #expect(crumbs.map(\.name) == ["/", "tmp"])
    }
}
