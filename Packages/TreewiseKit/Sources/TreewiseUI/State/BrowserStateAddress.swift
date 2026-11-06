import TreewiseCore

/// The path the address bar shows (ADR 0044, ADR 0069).
extension BrowserState {
    /// The folders from where the path starts to `folder`. The home folder, iCloud Drive
    /// and the other cloud folders start it themselves, as a volume does, the innermost
    /// when they hold each other. A path elsewhere on a volume starts with This Mac and
    /// the volume. A boundary folder, as `-TreewiseRoot` gives, starts it where it is.
    public func addressPath(of folder: FileItem.ID, boundary: [MountPoint]) -> [PathComponent] {
        let thisMac = PathComponent(
            name: FileItem.computer().name, path: FileItem.ID.computer.rawValue)
        guard folder != .computer else { return [thisMac] }
        let starts = locations.filter { [.volume, .home, .cloud].contains($0.kind) }
        let mounts = starts.map { MountPoint(path: $0.id.rawValue, name: $0.name) } + boundary
        let path = PathComponents.breadcrumbs(for: folder.rawValue, mountPoints: mounts)
        let volumes = Set(starts.filter { $0.kind == .volume }.map(\.id.rawValue))
        guard let first = path.first, volumes.contains(first.path) else { return path }
        return [thisMac] + path
    }
}
