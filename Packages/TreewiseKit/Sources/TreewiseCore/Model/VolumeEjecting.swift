/// Ejects volumes, for a provider whose volumes can be ejected (ADR 0044).
public protocol VolumeEjecting: Sendable {
    /// Unmounts and ejects the volume whose root is `volume`.
    ///
    /// - Throws: `FileSystemError.notEjected` with the system's reason when
    ///   the volume stays, for example because another app uses it.
    func eject(_ volume: FileItem.ID) async throws
}
