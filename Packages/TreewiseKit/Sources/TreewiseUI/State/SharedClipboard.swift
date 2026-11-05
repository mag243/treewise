import Observation

/// The clipboard every window of the app shares (ADR 0037), so items cut in
/// one window move when pasted in another.
@MainActor
@Observable
public final class SharedClipboard {
    /// The items cut or copied, waiting to be pasted.
    public internal(set) var contents: ClipboardModel?

    public init() {}
}
