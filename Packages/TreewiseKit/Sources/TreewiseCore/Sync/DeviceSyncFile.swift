import Foundation

/// A device's file in a drive's `.treewise/devices` folder (ADR 0144): which device wrote
/// it, its name for people, and its records. Only that device writes it.
public struct DeviceSyncFile: Hashable, Sendable {
    /// The format this version writes and reads.
    public static let format = 1

    /// The device's random id, made once per installation.
    public let device: String
    /// The device's name, as the system gives it.
    public let name: String
    /// The device's records, at most one per key.
    public let records: [SyncRecord]

    /// Why a file is not read.
    public enum Problem: Error, Equatable {
        /// A newer Treewise wrote it; it is kept and not written over.
        case newerFormat(Int)
    }

    /// A file of `records` by `device`, named `name`.
    public init(device: String, name: String, records: [SyncRecord]) {
        self.device = device
        self.name = name
        self.records = records
    }

    /// The file as JSON, its times to the fraction of a second, so two changes a moment
    /// apart keep their order.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Stored(file: self))
    }

    /// The file in `data`, skipping a record of a kind this version does not know.
    ///
    /// - Throws: `Problem.newerFormat` for a file a newer Treewise wrote; a decoding error
    ///   for one that is not a device's file.
    public static func decoded(from data: Data) throws -> DeviceSyncFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let header = try decoder.decode(Header.self, from: data)
        guard header.format <= format else { throw Problem.newerFormat(header.format) }
        return try decoder.decode(Stored.self, from: data).file
    }

    private struct Header: Decodable {
        let format: Int
    }

    private struct Stored: Codable {
        let format: Int
        let device: String
        let name: String
        let records: [Readable]

        init(file: DeviceSyncFile) {
            format = DeviceSyncFile.format
            device = file.device
            name = file.name
            records = file.records.map { Readable(record: $0) }
        }

        var file: DeviceSyncFile {
            DeviceSyncFile(device: device, name: name, records: records.compactMap(\.record))
        }
    }

    /// A record, or nothing for one this version cannot read, so the rest is still read.
    private struct Readable: Codable {
        let record: SyncRecord?

        init(record: SyncRecord) { self.record = record }

        init(from decoder: any Decoder) throws {
            record = try? SyncRecord(from: decoder)
        }

        func encode(to encoder: any Encoder) throws {
            try record?.encode(to: encoder)
        }
    }
}
