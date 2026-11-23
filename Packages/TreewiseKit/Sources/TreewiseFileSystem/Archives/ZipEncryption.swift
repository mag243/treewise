#if os(macOS)
    import Foundation

    /// Whether a zip's entries need a password, read from its central directory.
    ///
    /// tar checks a passphrase against zip's traditional encryption with one byte,
    /// so now and then a wrong one passes (about once in 140 tries on macOS 27) and
    /// the entry then fails as damaged data. The entries' own flag tells a locked zip from a damaged one.
    enum ZipEncryption {
        private enum Signature {
            static let entry: UInt32 = 0x0201_4b50
            static let end: UInt32 = 0x0605_4b50
            static let end64: UInt32 = 0x0606_4b50
            static let locator64: UInt32 = 0x0706_4b50
        }

        /// The end record's size without its comment, and the largest comment.
        private static let endSize = 22
        private static let commentLimit = Int(UInt16.max)
        private static let locator64Size = 20
        private static let entrySize = 46
        /// The general purpose flag that marks an encrypted entry.
        private static let encryptedFlag: UInt16 = 1
        /// A 32-bit field with this value has its real value in the zip64 record.
        private static let zip64Marker = UInt64(UInt32.max)
        /// The most central directory read, far beyond any real zip's.
        private static let directoryLimit: UInt64 = 64 << 20

        /// Whether any entry of the zip at `url` is encrypted; `false` for a file
        /// that is not a readable zip.
        static func hasEncryptedEntry(at url: URL) -> Bool {
            guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
            defer { try? handle.close() }
            guard let directory = centralDirectory(handle),
                directory.size <= directoryLimit,
                (try? handle.seek(toOffset: directory.offset)) != nil,
                let data = try? handle.read(upToCount: Int(directory.size))
            else { return false }
            return entriesEncrypted(Bytes(data))
        }

        /// Walks the central directory's entries and reads each one's flag.
        private static func entriesEncrypted(_ bytes: Bytes) -> Bool {
            var position = 0
            while position + entrySize <= bytes.count,
                bytes.uint32(at: position) == Signature.entry
            {
                if bytes.uint16(at: position + 8) & encryptedFlag != 0 { return true }
                let variable =
                    Int(bytes.uint16(at: position + 28)) + Int(bytes.uint16(at: position + 30))
                    + Int(bytes.uint16(at: position + 32))
                position += entrySize + variable
            }
            return false
        }

        /// The central directory's offset and size, from the end record, or from the
        /// zip64 end record when the end record points there.
        private static func centralDirectory(_ handle: FileHandle) -> (
            offset: UInt64, size: UInt64
        )? {
            guard let fileSize = try? handle.seekToEnd(), fileSize >= UInt64(endSize) else {
                return nil
            }
            let tailSize = min(fileSize, UInt64(endSize + commentLimit + locator64Size))
            let tailStart = fileSize - tailSize
            guard (try? handle.seek(toOffset: tailStart)) != nil,
                let data = try? handle.read(upToCount: Int(tailSize))
            else { return nil }
            let tail = Bytes(data)
            guard let end = lastEndRecord(in: tail) else { return nil }
            let size = UInt64(tail.uint32(at: end + 12))
            let offset = UInt64(tail.uint32(at: end + 16))
            guard size == zip64Marker || offset == zip64Marker else { return (offset, size) }
            let locator = end - locator64Size
            guard locator >= 0, tail.uint32(at: locator) == Signature.locator64 else { return nil }
            return zip64Directory(handle, at: tail.uint64(at: locator + 8))
        }

        private static func lastEndRecord(in tail: Bytes) -> Int? {
            stride(from: tail.count - endSize, through: 0, by: -1).first {
                tail.uint32(at: $0) == Signature.end
            }
        }

        private static func zip64Directory(
            _ handle: FileHandle, at recordOffset: UInt64
        ) -> (offset: UInt64, size: UInt64)? {
            let recordSize = 56
            guard (try? handle.seek(toOffset: recordOffset)) != nil,
                let data = try? handle.read(upToCount: recordSize), data.count == recordSize
            else { return nil }
            let record = Bytes(data)
            guard record.uint32(at: 0) == Signature.end64 else { return nil }
            return (record.uint64(at: 48), record.uint64(at: 40))
        }
    }

    /// Little-endian numbers in a zip's bytes; zero past the end.
    private struct Bytes {
        private let data: [UInt8]

        init(_ data: Data) {
            self.data = [UInt8](data)
        }

        var count: Int { data.count }

        func uint16(at offset: Int) -> UInt16 {
            UInt16(truncatingIfNeeded: value(at: offset, width: 2))
        }

        func uint32(at offset: Int) -> UInt32 {
            UInt32(truncatingIfNeeded: value(at: offset, width: 4))
        }

        func uint64(at offset: Int) -> UInt64 {
            value(at: offset, width: 8)
        }

        private func value(at offset: Int, width: Int) -> UInt64 {
            guard offset >= 0, offset + width <= data.count else { return 0 }
            return (0..<width).reduce(0) { sum, index in
                sum | UInt64(data[offset + index]) << (8 * index)
            }
        }
    }
#endif
