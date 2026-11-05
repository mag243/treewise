import Foundation
import Testing
import TreewiseFileSystem

// The mount table is the Mac's; iOS has no volumes to list (ADR 0045).
#if os(macOS)

    /// The kernel's table of mounted volumes, which This Mac lists (ADR 0046).
    @Suite struct MountTableTests {
        private static let startupVolume = URL(fileURLWithPath: "/")

        @Test func theStartupVolumeComesFirst() {
            #expect(MountTable.mountPoints().first == Self.startupVolume)
        }

        @Test func everyEntryIsAMountPoint() {
            for url in MountTable.mountPoints(includingHidden: true) {
                let fresh = URL(fileURLWithPath: url.path)
                #expect(
                    (try? fresh.resourceValues(forKeys: [.isVolumeKey]).isVolume) == true,
                    "\(url.path)")
            }
        }

        @Test func hiddenVolumesAreLeftOutUnlessAsked() {
            let browsable = Set(MountTable.mountPoints())
            let all = Set(MountTable.mountPoints(includingHidden: true))
            #expect(browsable.isSubset(of: all))
        }

        @Test func onlyMountedVolumesAmongTheGivenOnesAreSystemVolumes() {
            let missing = URL(fileURLWithPath: "/Volumes/Treewise Never Mounted")
            let volumes = LocalFileSystem.Locations.systemVolumes(among: [
                missing, Self.startupVolume,
            ])
            #expect(volumes == [Self.startupVolume])
        }
    }
#endif
