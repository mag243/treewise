/// The modifier keys held during a drag that change its mode (ADR 0003).
/// ⇧ plays no part.
public struct DropModifiers: OptionSet, Sendable, Hashable, CustomStringConvertible {
    /// The modifiers as bits.
    public let rawValue: Int

    /// Creates a set of modifiers from its bits.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// ⌥ Option: always copy.
    public static let option = DropModifiers(rawValue: 1 << 0)
    /// ⌘ Command: always move.
    public static let command = DropModifiers(rawValue: 1 << 1)

    /// The keys as symbols (`⌥⌘`), or `none`.
    public var description: String {
        let symbols = (contains(.option) ? "⌥" : "") + (contains(.command) ? "⌘" : "")
        return symbols.isEmpty ? "none" : symbols
    }
}
