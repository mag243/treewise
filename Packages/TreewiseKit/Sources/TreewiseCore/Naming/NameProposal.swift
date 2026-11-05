import Foundation

/// A name a module proposes for an item (ADR 0057). The data comes from a module
/// and is not trusted: `ProposedName` checks it before it can reach a file.
public struct NameProposal: Hashable, Sendable, Codable {
    /// The range a confidence is kept in.
    private static let confidenceRange = 0.0...1.0

    /// The proposed name, with or without the item's extension.
    public let name: String
    /// The module that made the proposal.
    public let moduleID: String
    /// How sure the module is, from 0 to 1. Anything else from a module is
    /// brought into that range, and what is not a number counts as 0.
    public let confidence: Double
    /// Whether `name` carries a new extension instead of the item's own.
    public let replacesExtension: Bool

    /// Creates a proposal.
    public init(
        name: String, moduleID: String, confidence: Double, replacesExtension: Bool = false
    ) {
        self.name = name
        self.moduleID = moduleID
        self.confidence =
            confidence.isNaN
            ? Self.confidenceRange.lowerBound
            : min(max(confidence, Self.confidenceRange.lowerBound), Self.confidenceRange.upperBound)
        self.replacesExtension = replacesExtension
    }

    /// Decodes a proposal through the checks of `init`, because it crosses from
    /// the module's process (ADR 0057).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            name: container.decode(String.self, forKey: .name),
            moduleID: container.decode(String.self, forKey: .moduleID),
            confidence: container.decode(Double.self, forKey: .confidence),
            replacesExtension: container.decode(Bool.self, forKey: .replacesExtension))
    }
}
