import UniformTypeIdentifiers

/// Whether a module handles a file, by the content types it declares (ADR 0057).
public enum ModuleScope {
    /// Whether `contentType` is one of `contentTypes`, or a subtype of one.
    public static func handles(contentTypes: Set<String>, contentType: String) -> Bool {
        guard let type = UTType(contentType) else { return false }
        return contentTypes.contains { UTType($0).map(type.conforms(to:)) ?? false }
    }
}
