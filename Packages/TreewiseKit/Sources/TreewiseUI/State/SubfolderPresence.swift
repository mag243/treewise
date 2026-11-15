/// Whether a folder has subfolders, as far as can be known without opening it (ADR 0108).
public enum SubfolderPresence: Hashable, Sendable {
    /// It has at least one.
    case present
    /// It has none.
    case absent
    /// Not known: reading it to find out would cost too much.
    case unknown
}
