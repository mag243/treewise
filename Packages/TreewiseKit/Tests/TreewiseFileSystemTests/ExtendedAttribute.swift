import Foundation

/// Reads and writes one extended attribute, for tests of what travels with an item.
enum ExtendedAttribute {
    static let testName = "me.m-domain.treewise.test"

    static func write(_ value: String, to url: URL, name: String = testName) throws {
        let result = value.withCString { bytes in
            setxattr(url.path, name, bytes, strlen(bytes), 0, 0)
        }
        guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    static func read(_ url: URL, name: String = testName) -> String? {
        let size = getxattr(url.path, name, nil, 0, 0, 0)
        guard size >= 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard getxattr(url.path, name, &bytes, size, 0, 0) == size else { return nil }
        return String(bytes: bytes, encoding: .utf8)
    }
}
