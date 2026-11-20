import Foundation

/// What a synced record holds: the whole of a folder's settings, a saved pattern, a
/// template, or the id of the default pattern (ADR 0144).
public enum SyncValue: Hashable, Sendable {
    case folder(FolderSettings)
    case savedPattern(SavedPattern)
    case defaultPattern(id: String)
    case template(FolderTemplate)
}

/// One change a device made, as it is written in its file in a drive's `.treewise` folder
/// (ADR 0144): a key, its value or its removal, when, and by which device.
///
/// Invariant: a value is of the kind its key names.
public struct SyncRecord: Hashable, Sendable {
    /// What the record is about.
    public let key: SyncKey
    /// The value, or nil when the thing was removed, forgotten or cleared.
    public let value: SyncValue?
    /// When the device made the change.
    public let changedAt: Date
    /// The id of the device that made it.
    public let device: String

    /// A record of `value` for `key`, nil for a removal.
    ///
    /// Precondition: `value` is of the kind `key` names.
    public init(key: SyncKey, value: SyncValue?, changedAt: Date, device: String) {
        precondition(
            value.map { Self.fits($0, key) } ?? true, "a value is of the kind its key names")
        self.key = key
        self.value = value
        self.changedAt = changedAt
        self.device = device
    }

    /// Whether the record is a removal.
    public var isRemoval: Bool { value == nil }

    static func fits(_ value: SyncValue, _ key: SyncKey) -> Bool {
        switch (key, value) {
        case (.folder, .folder), (.defaultPattern, .defaultPattern): true
        case (.savedPattern(let id), .savedPattern(let pattern)): pattern.id == id
        case (.template(let id), .template(let template)): template.id == id
        default: false
        }
    }
}

extension SyncRecord: Codable {
    private enum CodingKeys: String, CodingKey {
        case key, changedAt, device, value
    }

    /// Why a record is not read: its kind is unknown, or its value is not of that kind.
    public enum Problem: Error, Equatable {
        case unknownKey(String)
        case mismatchedValue(String)
    }

    /// Reads a record; one of a kind this version does not know throws `unknownKey`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .key)
        guard let key = SyncKey(text: text) else { throw Problem.unknownKey(text) }
        let value: SyncValue? =
            switch key {
            case .folder:
                try container.decodeIfPresent(FolderSettings.self, forKey: .value).map(
                    SyncValue.folder)
            case .savedPattern:
                try container.decodeIfPresent(SavedPattern.self, forKey: .value)
                    .map(SyncValue.savedPattern)
            case .defaultPattern:
                try container.decodeIfPresent(String.self, forKey: .value)
                    .map { SyncValue.defaultPattern(id: $0) }
            case .template:
                try container.decodeIfPresent(FolderTemplate.self, forKey: .value)
                    .map(SyncValue.template)
            }
        if let value, !Self.fits(value, key) { throw Problem.mismatchedValue(text) }
        self.key = key
        self.value = value
        changedAt = try container.decode(Date.self, forKey: .changedAt)
        device = try container.decode(String.self, forKey: .device)
    }

    /// Writes the record; a removal has no value.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key.text, forKey: .key)
        try container.encode(changedAt, forKey: .changedAt)
        try container.encode(device, forKey: .device)
        switch value {
        case nil: break
        case .folder(let settings): try container.encode(settings, forKey: .value)
        case .savedPattern(let pattern): try container.encode(pattern, forKey: .value)
        case .defaultPattern(let id): try container.encode(id, forKey: .value)
        case .template(let template): try container.encode(template, forKey: .value)
        }
    }
}
