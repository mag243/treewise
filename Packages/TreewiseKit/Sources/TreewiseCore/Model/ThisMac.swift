import Foundation

extension FileItem.ID {
    /// This Mac: the location that holds the volumes (ADR 0044). Not a path,
    /// so it never names an item on disk.
    public static let computer = FileItem.ID("treewise:computer")
}

extension FileItem {
    /// This Mac, with its name in `locale`: a top-level location of the kind
    /// `.computer`, whose contents are the volumes.
    public static func computer(locale: Locale = .current) -> FileItem {
        FileItem(
            id: .computer,
            name: String(
                localized: "This Mac", bundle: .module.localizationBundle(for: locale),
                locale: locale),
            kind: .computer, volume: VolumeID(FileItem.ID.computer.rawValue))
    }
}
