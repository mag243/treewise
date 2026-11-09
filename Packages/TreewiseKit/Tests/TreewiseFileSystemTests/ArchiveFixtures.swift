#if os(macOS)
    import Foundation
    import TreewiseTestSupport

    /// Archives for tests, made with the system's `tar` or written by hand.
    enum ArchiveFixtures {
        /// Stored archives of one file, `hello.txt`, as `tar` cannot write rar.
        static let rar4 =
            "UmFyIRoHAM+QcwAADQAAAAAAAAB2FHQAgCkAGgAAABoAAAAD3TMu9AAAIVoUMAkApIEAAGhlbGxvLnR4dEhlbGxv"
            + "IGZyb20gYSByYXIgYXJjaGl2ZS4KxD17AEAHAA=="
        static let rar5 =
            "UmFyIRoHAQDFGjMyAwEAAHCbgqIYAgIaBBqkgwLdMy70AAEJaGVsbG8udHh0SGVsbG8gZnJvbSBhIHJhciBhcmNo"
            + "aXZlLgoZsjo1AwUAAA=="

        /// The formats `tar` can write: an archive's name and the options that make it.
        static let writable: [(name: String, options: [String])] = [
            ("Photos.zip", ["--format", "zip"]),
            ("Photos.tar", ["--format", "pax"]),
            ("Photos.tar.gz", ["-z"]),
            ("Photos.tgz", ["-z"]),
            ("Photos.tar.bz2", ["-j"]),
            ("Photos.tar.xz", ["-J"]),
            ("Photos.7z", ["--format", "7zip"]),
            ("Photos.iso", ["--format", "iso9660"]),
            ("Photos.cpio", ["--format", "cpio"]),
            ("Photos.xar", ["--format", "xar"]),
        ]

        /// Runs the system's `tar` and waits for it.
        static func tar(_ arguments: [String]) throws {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = arguments
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
        }

        /// The entries of an archive, as tar lists them.
        static func list(_ archive: URL) throws -> [String] {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-tf", archive.path]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw CocoaError(.fileReadUnknown) }
            return (String(bytes: data, encoding: .utf8) ?? "").split(separator: "\n").map(
                String.init)
        }

        /// Makes the standard tree in `src`: a folder with a text file, a name
        /// with an accent, an executable, a link and an empty folder.
        static func makeTree(in directory: TempDirectory) throws {
            let manager = FileManager.default
            try directory.makeFolder("src/Photos/empty")
            try directory.makeFile("src/Photos/a.txt", contents: "hello")
            try directory.makeFile("src/Photos/Caf\u{E9}.txt", contents: "accent")
            let script = try directory.makeFile("src/Photos/run.sh", contents: "#!/bin/sh\n")
            try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
            try manager.createSymbolicLink(
                atPath: directory.url("src/Photos/link").path, withDestinationPath: "a.txt")
        }

        /// Writes a tar archive with entries of the given names, without the
        /// checks a real `tar` makes on what it writes. A link names its target.
        static func rawTar(_ entries: [(name: String, linkTarget: String?)]) -> Data {
            var data = Data()
            for entry in entries {
                let contents = entry.linkTarget == nil ? Data("evil".utf8) : Data()
                data += header(entry.name, size: contents.count, linkTarget: entry.linkTarget)
                data += contents
                data += Data(count: (blockSize - contents.count % blockSize) % blockSize)
            }
            return data + Data(count: 2 * blockSize)
        }

        private static let blockSize = 512

        private static func header(_ name: String, size: Int, linkTarget: String?) -> Data {
            var block = [UInt8](repeating: 0, count: blockSize)
            func put(_ text: String, at offset: Int) {
                block.replaceSubrange(offset..<offset + text.utf8.count, with: Array(text.utf8))
            }
            put(name, at: 0)
            put("0000644", at: 100)
            put("0000000", at: 108)
            put("0000000", at: 116)
            put(String(format: "%011o", size), at: 124)
            put("00000000000", at: 136)
            put(linkTarget == nil ? "0" : "2", at: 156)
            if let linkTarget { put(linkTarget, at: 157) }
            put("ustar", at: 257)
            put("00", at: 263)
            put("        ", at: 148)
            put(String(format: "%06o", block.reduce(0) { $0 + Int($1) }) + "\0 ", at: 148)
            return Data(block)
        }
    }
#endif
