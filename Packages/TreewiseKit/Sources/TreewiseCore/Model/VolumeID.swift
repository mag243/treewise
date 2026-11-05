/// Identifies the volume an item lives on. Dragging between volumes copies by
/// default (ADR 0003).
public struct VolumeID: Hashable, Sendable, CustomStringConvertible, ExpressibleByStringLiteral {
    /// The provider's identifier of the volume.
    public let rawValue: String

    /// Creates an identifier from the provider's raw value.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an identifier from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The raw value.
    public var description: String { rawValue }
}
