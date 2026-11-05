/// A mounted volume, as the path bar names it.
public struct MountPoint: Sendable, Hashable {
    /// Where the volume is mounted, such as `/` or `/Volumes/T7`.
    public var path: String
    /// The volume's name, such as `Macintosh HD`.
    public var name: String

    /// Creates a mount point.
    public init(path: String, name: String) {
        self.path = path
        self.name = name
    }
}

/// One segment of the path bar.
public struct PathComponent: Sendable, Hashable {
    /// What the segment shows.
    public var name: String
    /// The folder the segment stands for.
    public var path: String

    /// Creates a segment.
    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

/// Splits a path into the segments of the path bar: the volume first, then
/// one segment per folder.
public enum PathComponents {
    /// Returns the segments for an absolute path. The first segment is the
    /// volume whose mount point is the longest whole-component prefix of the
    /// path; without one, the root named `/`.
    ///
    /// Precondition: `path` starts with `/`.
    public static func breadcrumbs(for path: String, mountPoints: [MountPoint]) -> [PathComponent] {
        precondition(path.hasPrefix("/"), "path starts with /")
        let parts = components(of: path)
        let mount =
            mountPoints
            .map { (mount: $0, parts: components(of: $0.path)) }
            .filter { parts.starts(with: $0.parts) }
            .max { $0.parts.count < $1.parts.count }
        let volumeParts = mount?.parts ?? []
        var crumbs = [
            PathComponent(name: mount?.mount.name ?? "/", path: joined(volumeParts))
        ]
        for index in volumeParts.count..<parts.count {
            crumbs.append(PathComponent(name: parts[index], path: joined(parts[...index])))
        }
        return crumbs
    }

    private static func components(of path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    private static func joined(_ parts: some Collection<String>) -> String {
        "/" + parts.joined(separator: "/")
    }
}
