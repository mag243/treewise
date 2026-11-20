import Foundation

/// When and by which device a record was made: what a later record names as the one it
/// replaced (ADR 0144).
public struct SyncStamp: Hashable, Sendable, Codable {
    public let device: String
    public let changedAt: Date

    public init(device: String, changedAt: Date) {
        self.device = device
        self.changedAt = changedAt
    }
}

/// One part of an element as a device changed it, as it is written in its file in a drive's
/// `.treewise` folder (ADR 0144): the part, its value, when, by which device, and which
/// record it replaced on that device.
public struct SyncRecord: Hashable, Sendable {
    /// What the record is about.
    public let key: SyncKey
    /// The part's value; `null` for a part the element does not have.
    public let value: JSONValue
    /// When the device made the change.
    public let changedAt: Date
    /// The id of the device that made it.
    public let device: String
    /// The record of the part the device held when it made the change, if any.
    public let replaced: SyncStamp?

    /// A record of `value` for `key`.
    public init(
        key: SyncKey, value: JSONValue, changedAt: Date, device: String,
        replaced: SyncStamp? = nil
    ) {
        self.key = key
        self.value = value
        self.changedAt = changedAt
        self.device = device
        self.replaced = replaced
    }

    /// The record's own stamp.
    public var stamp: SyncStamp { SyncStamp(device: device, changedAt: changedAt) }

    /// Whether the record removes its element.
    public var isRemoval: Bool { key.part == SyncKey.exists && value == .bool(false) }
}

extension SyncRecord: Codable {
    private enum CodingKeys: String, CodingKey {
        case element, part, value, changedAt, device, replaced
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = SyncKey(
            try container.decode(SyncElement.self, forKey: .element),
            try container.decode(String.self, forKey: .part))
        value = try container.decodeIfPresent(JSONValue.self, forKey: .value) ?? .null
        changedAt = try container.decode(Date.self, forKey: .changedAt)
        device = try container.decode(String.self, forKey: .device)
        replaced = try container.decodeIfPresent(SyncStamp.self, forKey: .replaced)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key.element, forKey: .element)
        try container.encode(key.part, forKey: .part)
        try container.encode(value, forKey: .value)
        try container.encode(changedAt, forKey: .changedAt)
        try container.encode(device, forKey: .device)
        try container.encodeIfPresent(replaced, forKey: .replaced)
    }
}
