#if os(macOS)
    import Foundation

    /// A `git` Treewise can run without macOS asking to install one (ADR 0149).
    ///
    /// `/usr/bin/git` without the Command Line Tools opens macOS's question to install
    /// them, so it is never run to find out: the git of the developer directory
    /// `xcode-select -p` names comes first, then Homebrew's.
    public struct GitTool: Hashable, Sendable {
        /// The program, at a fixed path.
        public let executable: String

        /// Where Homebrew installs git, on Apple silicon and on Intel.
        public static let homebrewCandidates = ["/opt/homebrew/bin/git", "/usr/local/bin/git"]
        private static let xcodeSelect = "/usr/bin/xcode-select"

        /// Creates a tool that runs `executable`.
        public init(executable: String) {
            self.executable = executable
        }

        /// The git to use; `nil` when none is installed.
        ///
        /// - Parameters:
        ///   - developerDirectory: the folder of the Command Line Tools or Xcode, `nil`
        ///     without either.
        ///   - candidates: the other places git may be, in order.
        public static func find(
            developerDirectory: () -> String? = developerDirectory,
            candidates: [String] = homebrewCandidates
        ) -> GitTool? {
            let places = [developerDirectory().map { $0 + "/usr/bin/git" }].compactMap(\.self)
            return (places + candidates)
                .first { FileManager.default.isExecutableFile(atPath: $0) }
                .map(GitTool.init)
        }

        /// The developer directory `xcode-select -p` names, which asks nothing when there
        /// is none; `nil` then.
        public static func developerDirectory() -> String? {
            let output = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: xcodeSelect)
            process.arguments = ["-p"]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let path = String(bytes: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        }

        /// Asks macOS to install the Command Line Tools, which shows its own question.
        public static func requestInstall() {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: xcodeSelect)
            process.arguments = ["--install"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }
#endif
