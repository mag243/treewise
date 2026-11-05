/// Whether dates inside a folder's files can go without a look: they can when they
/// nearly always equal the dates in the names already there (ADR 0057).
public enum DateReliability {
    /// One file whose name and contents both hold a date.
    public struct Sample: Hashable, Sendable {
        /// The date in its name.
        public let inName: NameTemplate.Value
        /// The date inside the file.
        public let insideFile: NameTemplate.Value

        /// Creates a sample.
        public init(inName: NameTemplate.Value, insideFile: NameTemplate.Value) {
            self.inName = inName
            self.insideFile = insideFile
        }
    }

    /// With fewer files than this, agreement can be chance.
    public static let minimumSamples = 5
    /// The share of the files that must agree.
    public static let requiredShare = 0.9

    /// Whether these files show that dates inside files are reliable in their folder.
    public static func isReliable(_ samples: [Sample]) -> Bool {
        guard samples.count >= minimumSamples else { return false }
        let agreeing = samples.count { $0.inName == $0.insideFile }
        return Double(agreeing) >= Double(samples.count) * requiredShare
    }
}
